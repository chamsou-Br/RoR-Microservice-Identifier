# frozen_string_literal: true

require "sidekiq/api"
# == Schema Information
#
# Table name: graphs
#
#  id                      :integer          not null, primary key
#  uid                     :string(255)
#  title                   :string(255)      not null
#  type                    :string(255)
#  level                   :integer
#  state                   :string(255)
#  reference               :string(255)
#  domain                  :text(65535)
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  version                 :string(255)
#  model_id                :integer
#  purpose                 :string(12000)
#  directory_id            :integer
#  customer_id             :integer
#  comment_index_int       :boolean          default(TRUE)
#  author_id               :integer
#  parent_id               :integer
#  news                    :string(765)
#  groupgraph_id           :integer
#  confidential            :boolean          default(FALSE)
#  svg                     :text(16777215)
#  pilot_id                :integer
#  tree                    :boolean          default(FALSE)
#  print_footer            :string(100)
#  read_confirm_reminds_at :datetime
#  graph_background_id     :integer
#  imported_package_id     :integer
#  imported_uid            :string(255)
#  imported_groupgraph_uid :string(255)
#
# Indexes
#
#  fk_graphs_groupgraph          (groupgraph_id)
#  index_graphs_on_author_id     (author_id)
#  index_graphs_on_customer_id   (customer_id)
#  index_graphs_on_directory_id  (directory_id)
#  index_graphs_on_level         (level)
#  index_graphs_on_model_id      (model_id)
#  index_graphs_on_parent_id     (parent_id)
#  index_graphs_on_pilot_id      (pilot_id)
#  index_graphs_on_reference     (reference)
#  index_graphs_on_state         (state)
#  index_graphs_on_title         (title)
#  index_graphs_on_updated_at    (updated_at)
#
class Graph < ApplicationRecord
  include Contributable
  # Elasticsearch
  include SearchableGraph
  # TODO: create a state machine for graphs.
  include Workflow
  include GraphsHelper
  include Sanitizable
  include Discussion::Discussable
  include PrintableFooter
  include EntityExporter

  include LinkableFieldable

  sanitize_fields :domain, :news, :print_footer, :purpose, :reference, :title

  discussable_by :author, :contributors

  attr_accessor :confirm_read

  has_many :graphs_roles, dependent: :destroy
  has_many :roles, through: :graphs_roles

  belongs_to :model, optional: true

  has_many :elements, -> { order "zindex asc" }, dependent: :destroy
  has_many :arrows, dependent: :destroy
  has_many :lanes, dependent: :destroy

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  has_many :favorites, as: :favorisable, dependent: :destroy

  belongs_to :directory, optional: true
  belongs_to :customer

  # @!attribute [rw] author
  #   @return [User]
  belongs_to :author, foreign_key: "author_id", class_name: "User"
  belongs_to :pilot, foreign_key: "pilot_id", class_name: "User", optional: true

  belongs_to :groupgraph, optional: true

  belongs_to :background,
             foreign_key: "graph_background_id",
             class_name: "GraphBackground",
             optional: true

  has_many :likers, through: :favorites, source: :user

  # Actors

  has_many :graphs_viewers, dependent: :destroy
  has_many :viewers, through: :graphs_viewers, source_type: "User"
  has_many :viewergroups, through: :graphs_viewers, source_type: "Group", source: :viewer
  has_many :viewerroles, through: :graphs_viewers, source_type: "Role", source: :viewer

  has_many :graphs_verifiers, dependent: :destroy
  has_many :verifiers, -> { where "graphs_verifiers.historized = ?", false }, through: :graphs_verifiers

  has_many :graphs_approvers, dependent: :destroy
  has_many :approvers, -> { where "graphs_approvers.historized = ?", false }, through: :graphs_approvers

  # @!attribute [rw] graph_publisher
  #   @return [GraphPublisher]
  has_one :graph_publisher, dependent: :destroy

  # @!attribute [rw] publisher
  #   @return [User]
  has_one :publisher, through: :graph_publisher

  has_many :graphs_logs, dependent: :destroy

  has_many :impactables_impacts, as: :impact, dependent: :destroy
  has_many :events, through: :impactables_impacts, source: :impactable, source_type: "Event"
  has_many :acts, through: :impactables_impacts, source: :impactable, source_type: "Act"
  has_many :risks, through: :impactables_impacts, source: :impactable, source_type: "Risk"

  has_many :read_confirmations, as: :process, dependent: :destroy

  has_many :graph_steps, dependent: :destroy

  # /Actors

  # FIXME: This `parent/child` semantic seems to be the way to do the
  #        versioning of graphs before `Groupgraph`s was introduced.
  #        This does not seem to be used anymore,
  has_one :child, class_name: "Graph", foreign_key: "parent_id"
  belongs_to :parent, class_name: "Graph", optional: true

  self.inheritance_column = nil
  validates :level, inclusion: { in: [1, 2, 3] }
  validates :type, inclusion: { in: %w[process human environment] }
  validates :state, inclusion: {
    in: %w[new verificationInProgress approvalInProgress approved applicable deactivated archived]
  }
  validates :reference, presence: true,
                        uniqueness: { is: true, scope: %i[customer_id version] }
  # no control for version
  # validates :version, :format => { :with => /^\S+\.*\S*$/ }

  validates :title, presence: true,
                    uniqueness: { is: true, scope: %i[customer_id version] }
  validates :directory, presence: true
  validates :author, presence: true
  validates :purpose, length: { maximum: 12_000 }
  validates :domain, length: { maximum: 65_535 }

  validate  :check_version
  validate  :check_model

  before_create do |graph|
    graph.model = customer.models.find_by_type_and_level_and_tree(type, level, tree)
    # Pour un nouveau graph (le premier d'un groupgraph), il faut créer le groupgraph
    if graph.groupgraph_id.nil?
      graph.groupgraph = Groupgraph.create(customer_id: graph.customer_id,
                                           type: graph.type,
                                           level: graph.level,
                                           tree: graph.tree,
                                           auto_role_viewer: true)
    end
  end

  before_create :generate_uid

  scope :applicable, -> { where(state: :applicable) }
  scope :available, -> { where.not(state: :archived).where.not(state: :deactivated) }

  def all_versions
    groupgraph.graphs
  end

  
  # TODO: there is a serializer already at app/serializers/graph_serializer.rb
  # but with too much informations. Need to do a manual serialiazer as other
  # parts (ElasticSearch) count on the default as_json method, so it cannot be
  # overwritten.
  def serialize_this
    as_json(only: %i[id title level purpose domain])
  end

  def self.latest_published(user, number)
    GraphPolicy::Scope
      .new(user, nil)
      .resolve
      .joins(:graphs_logs)
      .merge(GraphsLog.where(action: "published"))
      .where(state: "applicable")
      .order("graphs_logs.created_at desc")
      .limit(number)
  end

  #
  # Is the provided `user` concerned with this graph?  This is true if the user
  # is assigned a concerned {Role} (where `concern: true`) related to this
  # graph.
  #
  # @param user [User]
  # @return [Boolean]
  # @todo Use `#exists?` instead of `#count >= 1`
  #
  def concerned_by?(user)
    graphs_roles.where(role_id: user.concerned_roles).count >= 1
  end

  #
  # Graphs with which the given `user` is concerned.
  #
  # @param user [User]
  # @return [ActiveRecord::Relation<Graph>]
  # @todo Rewrite this as a scope for query composition
  #
  def self.concerned_by(user)
    Graph.includes(:graphs_roles)
         .where("graphs_roles.role_id" => user.concerned_roles)
  end

  def self.types
    Groupgraph.types
  end

  def self.levels
    Groupgraph.levels
  end

  def level_with_tree
    (level == 3) && tree ? "tree" : level
  end

  # This appears to be expected in a few places.  However, `level_with_tree`
  # cannot be removed either as it too is expected.
  # TODO: Use only one of these, probably `level_and_tree` to be consistent
  # with setter
  alias level_and_tree level_with_tree

  def level_and_tree=(value)
    if value == "tree"
      self.level = 3
      self.tree = true
    else
      self.level = value.to_i
      self.tree = false
    end
  end

  ##
  # Return all prossible state a graph can be in.
  #
  # FIXME : This is a duplication of the above `validates :state, inclusion:` values
  #
  def self.states
    %w[new verificationInProgress approvalInProgress approved applicable deactivated archived]
  end

  ##
  # Return states in which a graph is not stable, in the publishing progress.
  #
  # @note This is used to check if a new version of the graph can be created.
  #       A graph can only have one new version that is in preparation.
  #       (several stable versions but only one unstable)
  # @note This is exactly the same rule with Documents
  #
  def self.unstable_states
    %w[new verificationInProgress approvalInProgress approved]
  end

  def filter_roles(roles_list)
    roles_to_remove = roles - roles_list
    roles_to_remove.each do |role|
      graph_role_link = GraphsRole.find_by_role_id_and_graph_id(role.id, id)
      graph_role_link&.delete
    end
  end

  def action_date(action)
    graphs_logs.where(action: action).last
  end

  def contribution_editable?
    in_edition?
  end

  def in_edition?
    state == "new"
  end

  # rubocop:disable Naming/PredicateName
  def is_verified?
    graphs_verifiers.count.positive? && graphs_verifiers.find_by_verified_and_historized(false, false).nil?
  end

  def in_verification?
    state == "verificationInProgress"
  end

  def delete_verifier(user)
    logger.debug "==========> Graph#delete_verifier"
    graphs_verifiers.delete(graphs_verifiers.where(verifier_id: user, historized: false))
    verifiers.reload
  end

  def is_approved?
    graphs_approvers.count.positive? && graphs_approvers.find_by_approved_and_historized(false, false).nil?
  end
  # rubocop:enable Naming/PredicateName

  def in_approval?
    state == "approvalInProgress"
  end

  def delete_approver(user)
    graphs_approvers.delete(graphs_approvers.where(approver_id: user, historized: false))
  end

  # rubocop:disable Naming/PredicateName
  def is_published?
    !graph_publisher.nil? && graph_publisher.published
  end
  # rubocop:enable Naming/PredicateName

  def in_publication?
    (state == "approved") && scheduler_get_publish_job.nil?
  end

  def in_scheduled_publication?
    (state == "approved") && !scheduler_get_publish_job.nil?
  end

  #
  # Publish the graph optionally as an Administrator
  #
  # @param [User, nil] admin
  #
  # @return [Boolean] `true` if the graph was published or `false` otherwise
  #
  def publish(admin = nil)
    graph_publisher.published = true
    if graph_publisher.save
      scheduler_del_publish_job # in case Sidekiq fails to remove it
      comment = if admin.nil?
                  nil
                else
                  I18n.t("controllers.graphs.admin_publish.published_comment",
                         admin: admin.name.full,
                         user: publisher.name.full)
                end
      publisher = admin.nil? ? self.publisher : admin

      GraphsLog.create(graph_id: id, user_id: publisher.id, action: "published_by", comment: comment)
      next_state publisher
      true
    else
      false
    end
  end

  def publish_on(date)
    scheduler_del_publish_job
    graph_publisher.publish_date = date
    if graph_publisher.save
      !scheduler_add_publish_job.nil?
    else
      false
    end
  end

  def publish_date
    state == "approved" && !graph_publisher.nil? ? graph_publisher.publish_date : nil
  end

  # Return a hash where each pair is composed by
  # [key] a iso8601 publication date
  # [val] an array containing each graph
  def self.publish_agenda(customer, filter_id)
    graphs = {}
    # customer.graphs.all(:conditions => 'state = "approved"').each do |graph|
    customer.graphs.where(state: "approved").each do |graph|
      next if graph.publish_date.nil? || (graph.id == filter_id)

      date = graph.publish_date
      next unless date

      iso = date.iso8601
      graphs[iso] ||= []
      graphs[iso] << graph.as_json(only: %i[id title])
    end
    graphs
  end

  def in_application?
    state == "applicable"
  end

  def in_archives?
    state == "archived"
  end

  # rubocop:disable Naming/PredicateName
  def is_deactivated?
    state == "deactivated"
  end
  # rubocop:enable Naming/PredicateName

  def archive
    self.state = "archived"
    save
  end

  def deactivate
    self.state = "deactivated"
    save
  end

  def activate
    self.state = "applicable"
    save
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def reset_state(sender)
    if in_verification? || in_approval?
      verifiers.each do |user|
        row = graphs_verifiers.where(verifier_id: user.id, historized: false).first
        row.historized = true
        graphs_verifiers.create(verifier_id: user.id) if row.save
      end
      verifiers.reload
    end
    if in_approval?
      approvers.each do |user|
        row = graphs_approvers.where(approver_id: user.id, historized: false).first
        row.historized = true
        graphs_approvers.create(approver_id: user.id) if row.save
      end
      approvers.reload
    end
    old_state = state
    self.state = "new"
    notify_state_change(sender, old_state, state)
    save
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  def self.ordered_for_ihm(graphs)
    res = []
    Graph.types.each do |type|
      res += graphs.where(type: type).order("level, title")
    end
    res
  end

  # rubocop:disable Naming/MethodName
  # TODO: there seems to be other ways of findind this out
  def isNewRecord
    elements.blank? && roles.blank? && lanes.blank? && arrows.blank?
  end
  # rubocop:enable Naming/MethodName

  ##
  # Increment the version of the graph by duplicating the current one
  # and keeping it associated to the groupgraph, which contains all graph's versions.
  #
  # The new version is created only if there is no other unstable version of the graph
  # (that is in the publishing process).
  #
  # @note Not to be confused with `duplicate`
  #
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def increment_version(next_version)
    # @graph.child après le duplicate pour récupérer le graph dupliqué.
    if check_increment_version
      graph_duplicated = dup # duplicate the current attributes
      graph_duplicated.attributes = {
        svg: nil,
        version: next_version,
        state: "new",
        news: nil,
        author: groupgraph.last_available.author
      }
      graph_duplicated.parent = self
      graph_duplicated.contributors = contributors.reject(&:deactivated?)
      graph_duplicated.uid = nil
      graph_duplicated.imported_package_id = nil
      graph_duplicated.imported_uid = nil
      graph_duplicated.imported_groupgraph_uid = nil
      if graph_duplicated.save
        GraphsViewer.duplicate_for(graph_duplicated)
        GraphsVerifier.duplicate_for(graph_duplicated)
        GraphsApprover.duplicate_for(graph_duplicated)
        GraphPublisher.duplicate_for(graph_duplicated)
        GraphsRole.duplicate_for(graph_duplicated)
        Tagging.duplicate_for(graph_duplicated)
        Element.duplicate_for(graph_duplicated)
        Favorite.duplicate_for(graph_duplicated)
        return true
      end
    end
    false
  end

  ##
  # Increment the version of the graph by duplicating the current graph
  # but by untiyng the groupgraph, which is the link between all graph's versions.
  # Therefore, this created graph will be standalone with its own groupgraph.
  #
  # @note Not to be confused with `increment_version`
  #
  def duplicate(graph_parameters, current_user)
    graph_duplicated = dup # duplicate the current attributes
    graph_duplicated.attributes = {
      svg: nil,
      version: graph_parameters[:version],
      state: Graph.states.first,
      news: nil,
      reference: graph_parameters[:reference],
      title: graph_parameters[:title],
      parent_id: nil
    }
    graph_duplicated.author = current_user
    graph_duplicated.contributors = contributors

    # The duplicated graph must have a brand new `groupgraph`.
    # Therefore, we set it as `nil` for it to be generated in the `before_create`
    graph_duplicated.groupgraph = nil
    graph_duplicated.uid = nil
    graph_duplicated.imported_package_id = nil
    graph_duplicated.imported_uid = nil
    graph_duplicated.imported_groupgraph_uid = nil
    if graph_duplicated.save
      GraphsViewer.duplicate_for(graph_duplicated, self)
      GraphsVerifier.duplicate_for(graph_duplicated, self)
      GraphsApprover.duplicate_for(graph_duplicated, self)
      GraphPublisher.duplicate_for(graph_duplicated, self)
      GraphsRole.duplicate_for(graph_duplicated, self)
      Tagging.duplicate_for(graph_duplicated, self)
      Element.duplicate_for(graph_duplicated, self)
      GraphsLog.create(
        graph_id: graph_duplicated.id,
        user_id: graph_duplicated.author_id,
        action: "created", comment: nil
      )
    end
    graph_duplicated
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Naming/PredicateName
  def is_current_state(possible_state)
    state == possible_state
  end
  # rubocop:enable Naming/PredicateName

  ##
  # Return the previous versions of the graph, i.e. its parents
  #
  # FIXME: This `parent/child` semantic seems to be the way to do the
  #        versioning of graphs before `Groupgraph`s was introduced.
  #        This does not seem to be used anymore,
  #
  def ancestors
    current_document = self
    array_of_ancestors = []
    until current_document.parent.nil?
      array_of_ancestors << current_document.parent
      current_document = current_document.parent
    end
    array_of_ancestors
  end

  ##
  # Return the list of all versions of the graph,
  # i.e. all graphs in the `groupgraph`
  #
  def versions_list
    groupgraph.graphs.order(created_at: "DESC")
  end

  def linked_graphups
    res = []
    groupgraph_ids = []
    elements.where(shape: "graphup").each do |element|
      groupgraph_ids << element.model_id
    end
    customer.groupgraphs.where(id: groupgraph_ids).each do |groupgraph|
      res << groupgraph.applicable_version_or_last_available
    end
    res
  end

  def linked_graphdownstreams
    res = []
    groupgraph_ids = []
    elements.where(shape: "graphdownstream").each do |element|
      groupgraph_ids << element.model_id
    end
    customer.groupgraphs.where(id: groupgraph_ids).each do |groupgraph|
      res << groupgraph.applicable_version_or_last_available
    end
    res
  end

  def linked_roles
    res = []
    role_ids = []
    elements.where(shape: "role").each do |element|
      role_ids << element.model_id
    end
    customer.roles.where(id: role_ids).each do |role|
      res << role
    end
    res
  end

  def linked_internal_roles
    customer.roles.where id: elements.where(shape: "role", type: %w[intern unit]).pluck(:model_id)
  end

  def linked_documents
    res = []
    document_ids = []
    elements.where(shape: "document").each do |element|
      document_ids << element.model_id
    end
    customer.documents.where(id: document_ids).each do |document|
      res << document
    end
    res
  end

  def linked_resources
    customer.resources.where(id: elements.where("shape = ? AND model_id IS NOT NULL", "resource").pluck(:model_id))
  end

  #
  # Update this graph's `author` with the user matching the given `author_id`
  #
  # @param [User] current_user
  # @param [Integer, String] author_id
  #
  # @return [Boolean] `true` if the author was updated or `false` otherwise
  #
  def change_author(current_user, author_id)
    self.author = current_user.customer.active_power_users.find(author_id)

    return false unless save

    # Notify the new author that they are now the author of this entity
    NewNotification.create_and_deliver(customer: current_user.customer,
                                       category: :change_author,
                                       from: current_user,
                                       to: author,
                                       entity: self)

    # Log the change of author for this entity
    # @type [User]
    new_author = current_user.customer.users.find(author_id)
    GraphsLog.create(
      graph_id: id,
      user_id: author_id,
      action: "change_author",
      comment: I18n.t("helpers.graphs.humanize_log.change_author_by",
                      author: new_author.name.full,
                      admin: current_user.name.full)
    )

    true
  end

  #
  # Update this graph's pilot to the user matching the given `pilot_id`
  #
  # @param [User] current_user
  # @param [Integer, String] pilot_id
  #
  # @return [Boolean] `true` if the pulot was updated or `false` otherwise
  #
  def change_pilot(current_user, pilot_id)
    is_new_pilot = pilot.nil?
    self.pilot = current_user.customer.users.find(pilot_id)

    return false unless save

    # Notify the new pilot that they are now the pilot for this entity
    NewNotification.create_and_deliver(customer: current_user.customer,
                                       category: :change_pilot,
                                       from: current_user,
                                       to: pilot,
                                       entity: self)

    # Log the change of pilot for this entity
    # @type [User]
    new_pilot = current_user.customer.users.find(pilot_id)
    GraphsLog.create(
      graph_id: id,
      user_id: pilot_id,
      action: is_new_pilot ? "new_pilot" : "change_pilot",
      comment: I18n.t("helpers.graphs.humanize_log.#{is_new_pilot ? 'set' : 'change'}_pilot_by",
                      pilot: new_pilot.name.full,
                      user: current_user.name.full)
    )

    true
  end

  def rootable?
    in_application? && type == "process" && level == 1
  end

  def root
    groupgraph.root
  end

  # rubocop:disable Naming/AccessorMethodName
  # TODO: this method has the wrong name, wrong return statements.
  def set_root(p_root)
    if rootable?
      customer.groupgraphs.where(root: true).each do |groupgraph_to_unroot|
        groupgraph_to_unroot.root = false
        groupgraph_to_unroot.save
      end
      groupgraph.root = p_root
      groupgraph.save
      return true
    end
    false
  end
  # rubocop:enable Naming/AccessorMethodName

  def ordered_commented_entities
    commented_entities = []
    commented_entities += elements.where("comment <> ''").order("y ASC")
    commented_entities += arrows.where("comment <> ''").order("y ASC")
    commented_entities.sort_by! { |entity| [entity.y, entity.x] }
  end

  # INTERACTIONS
  #
  # Returns all the parent graphs, taken from the linked groupgraph,
  # excluding the :archived graphs.
  #
  def parent_graphs
    Graph.includes(:elements).where(
      elements: {
        model_type: "Groupgraph",
        model_id: groupgraph_id,
        shape: Element.actions_shapes_linkable_to_graph
      }
    ).where.not(state: "archived").distinct
  end

  # Returns all the childrengraphs, taken from the linked groupgraph,
  # excluding the :archived graphs.
  #
  def child_graphs
    all_children = children_actions.map(&:graphs).flatten

    all_children.reject { |g| g.state == "archived" }
  end

  # group_graphs des formes actions pointant vers ce graphe.
  #
  # Returns the Groupgraphs when it included in an element, whose groupgraph
  # id the one from this graph. IOW, it returns the parent groupgraphs.
  #
  def parents_actions
    Groupgraph.includes([graphs: :elements]).where(
      elements: {
        model_type: "Groupgraph",
        model_id: groupgraph_id,
        shape: Element.actions_shapes_linkable_to_graph
      }
    ).distinct
  end

  # NOTE: the following two methods are almost identical. Both return the list
  # of groupgraphs found in elements with the provided shapes. In
  # `children_actions` this list is `%w[processus instruction
  # collaborative-instruction operation]` and for `children_graphs` it is
  # `%w[processus instruction collaborative-instruction operation
  # graphdownstream]`, so it include the shape `graphdownstream` with respect
  # to the previous.
  #
  # Returns the ids of the Groupgraphs that are linked in elements of this
  # graph. This are the children groupgraphs of the graph.
  #
  def children_actions
    Groupgraph.where(
      id: elements.where(model_type: "Groupgraph",
                         shape: Element.actions_shapes_linkable_to_graph)
                  .pluck(:model_id)
    )
              .distinct
  end

  # Also returns the ids of the Groupgraphs that are linked in elements of this
  # graph. This are the children groupgraphs of the graph.
  #
  def children_graphs
    Groupgraph.where(
      id: elements.where(model_type: "Groupgraph",
                         shape: %w[processus instruction
                                   collaborative-instruction operation
                                   graphdownstream])
                  .pluck(:model_id)
    ).distinct
  end

  # This method returns the `text` found in the `element` of the parent graph
  # to which it is connected. If the `text` in the `element` is the same as the
  # `title` of the `graph`, it returns nil.
  #
  # @param [Grapht]
  # @return [String] if an alias exists
  # @return nil if no alias exists, if no `element` was found
  #             or @param is not a Graph
  #
  def alias_in_parent(parent_graph)
    return unless parent_graph.instance_of?(Graph)

    element = parent_graph.elements.find_by(
      model_id: groupgraph_id,
      model_type: "Groupgraph",
      shape: Element.actions_shapes_linkable_to_graph
    )

    return unless element
    return if element.text == title

    element.text
  end

  def children_documents
    Groupdocument.where(id: elements.where(model_type: "Groupdocument")
                 .pluck(:model_id)).distinct
  end

  def children_resources
    Resource.where(id: elements.where(model_type: "Resource").pluck(:model_id))
  end

  def children_roles
    Role.where(id: elements.where(model_type: "Role").pluck(:model_id))
  end

  def active_children_resources
    Resource.active.where(id: elements.where(model_type: "Resource").pluck(:model_id))
  end

  def active_children_roles
    Role.where(id: elements.where(model_type: "Role").pluck(:model_id), deactivated: false)
  end

  def documents_elmnts
    return [] unless (2..3).cover?(level)

    children_group_documents = elements.where(model_type: "Groupdocument",
                                              shape: Element.actions_shapes_linkable_to_graph)
                                       .distinct
    doc_elements = elements.where(shape: "document")
    doc_elements + children_group_documents
  end

  def resources_elmnts
    return [] unless (2..3).cover?(level)

    elements.where(shape: "resource")
  end

  def inputs_elmnts
    return [] unless (2..3).cover?(level)

    elements.where(shape: %w[graphup graphstart])
  end

  # Get inputs elements directly from start point of graph
  # where starts means elements shaped as "graphup" or "graphstart"
  # eg: Start -> [panier] -> instruction will get "panier"
  def inputs_elments_input_data
    inputs_elmnts.each_with_object([]) do |arrow, array|
      array << arrow.arrow_out if arrow.arrow_out
    end
  end

  # Get outputs elements from graphdownstream and graphend elements
  # eg: Instruction -> [panier] -> end will get "panier"
  def outputs_elments_output_data
    outputs_elmnts.each_with_object([]) do |arrow, array|
      array << arrow.arrow_in if arrow.arrow_in
    end
  end

  def outputs_elmnts
    return [] unless (2..3).cover?(level)

    elements.where(shape: %w[graphdownstream graphend])
  end

  def arrow_inputs_main_process
    return [] unless level == 1 && !main_process.nil?

    main_process_and_descendants = main_process.self_and_descendants
    arrows.where(to: main_process_and_descendants).where.not(from: main_process_and_descendants)
  end

  def arrow_outputs_main_process
    return [] unless level == 1 && !main_process.nil?

    main_process_and_descendants = main_process.self_and_descendants
    arrows.where(from: main_process_and_descendants).where.not(to: main_process_and_descendants)
  end

  def main_process
    elements.where(main_process: true).first
  end

  # END INTERATIONS

  def comment_wf_max_length
    765
  end

  def self.related_role_graphs(role_ids)
    includes(:graphs_roles).where(state: ["applicable"],
                                  graphs_roles: { role_id: role_ids })
                           .distinct
                           .order(title: "ASC")
  end

  def self.related_role_graphs_to_admin_or_designer(role_ids)
    includes(:graphs_roles).where(
      state: %w[applicable new verificationInProgress approvalInProgress approved deactivated],
      graphs_roles: { role_id: role_ids }
    ).distinct.order(title: "ASC", state: "ASC", version: "ASC")
  end

  # rubocop:disable Naming/PredicateName
  def has_deactivated_actors?
    involved_users = (verifiers.to_a + approvers.to_a + [publisher]).uniq
    involved_users.any? { |user| user&.deactivated? }
  end
  # rubocop:enable Naming/PredicateName

  ##
  # Return the url of the applicable version of the current graph.
  # It's just the groupgraph url, which redirect to the applicable version.
  #
  def permalink(request)
    request_info = { protocol: request.protocol, host: request.host, port: request.port }

    Rails.application.routes.url_helpers
         .groupgraph_url(groupgraph, **request_info)
  end

  ##
  # Return the url of the current graph.
  #
  def url(request)
    request_info = { protocol: request.protocol, host: request.host, port: request.port }

    Rails.application.routes.url_helpers
         .graph_url(self, **request_info)
  end

  
  def triggering_permalinks(input_or_output = "inputs")
    send("#{input_or_output}_elmnts").each_with_object([]) do |element, array|
      next unless element.model_id

      array << Rails.application.routes.url_helpers.url_for(
        controller: element.model_type.underscore.pluralize,
        action: :show,
        id: element.model_id,
        only_path: false,
        protocol: "https",
        host: customer.url
      )
    end
  end

  KEYS = %w[
    title reference level state_humanize version purpose domain author
    publisher pilot changed_pilot_at validation_sent_at verifiers approvers
    confidential created_at updated_at published_at deactivated_at
    permalink url tags news parents parents_permalink parents_link children
    children_permalink children_link roles inputs_elmnts inputs_triggering
    inputs_triggering_permalink outputs_elmnts outputs_triggering
    outputs_triggering_permalink nb_events events_title events_links nb_risks
    risks_title risks_links contributors last_review_date next_review_date
    breadcrumb_str
  ]

  

  def self.default_export_keys(options = {})
    
    export_read_confirmations = options[:customer].settings.approved_read_graph?
    options.delete(:customer)

    keys = KEYS
    keys += %w[nb_viewers reading_rate] if export_read_confirmations
    special_keys = {
    author: ->(e) { e.author.name.full },
    publisher: ->(e) { (e.publisher.nil? ? "" : e.publisher.name.full) },
    pilot: ->(e) { (e.pilot.nil? ? "" : e.pilot.name.full) },
    verifiers: ->(e) { e.verifiers.map(&:name).map(&:full).join(", ") },
    approvers: ->(e) { e.approvers.map(&:name).map(&:full).join(", ") },
    confidential: lambda { |e|
      I18n.t("helpers.graphs.humanize_confidentiality.#{e.confidential}")
    },
    permalink: ->(e) { e.permalink(options[:request]) },
    url: ->(e) { e.url(options[:request]) },
    tags: ->(e) { e.tags.pluck(:label).join(",") },
    contributors: ->(e) { e.display_contributors },
    nb_events: ->(e) { e.events.count },
    parents: ->(e) { e.parents_actions.pluck(:title).join(",") },
    children_permalink: lambda { |e|
      e.children_actions.all.map do |gg|
        gg.last_active_available&.permalink(options[:request])
      end.join(",")
    },
    children_link: lambda { |e|
      e.children_actions.all.map do |gg|
        gg.last_active_available&.url(options[:request])
      end.join(",")
    },
    roles: ->(e) { e.linked_roles.pluck(:title).join(",") },
    inputs_elmnts: lambda { |e|
      e.inputs_elments_input_data.pluck(:text).join(",")
    },
    inputs_triggering: lambda { |e|
      e.inputs_elmnts.pluck(:text).join(",")
    },
    inputs_triggering_permalink: lambda { |e|
      e.triggering_permalinks.join(",")
    },
    outputs_elmnts: lambda { |e|
      e.outputs_elments_output_data.pluck(:text).join(",")
    },
    outputs_triggering: lambda { |e|
      e.outputs_elmnts.pluck(:text).join(",")
    },
    outputs_triggering_permalink: lambda { |e|
      e.triggering_permalinks("outputs").join(",")
    },
    events_links: ->(e) { e.events_links.join(",") },
    parents_permalink: lambda { |e|
      e.parents_actions.all.map do |gg|
        gg.last_active_available&.permalink(options[:request])
      end.join(",")
    },
    parents_link: lambda { |e|
      e.parents_actions.all.map do |gg|
        gg.last_active_available&.url(options[:request])
      end.join(",")
    },
    nb_risks: ->(e) { e.risks.count }
  }
  if export_read_confirmations
    special_keys[:nb_viewers] = lambda { |e|
      e.in_application? ? e.all_viewers.count : ""
    }
  end


    [keys, special_keys]
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength,
  # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
  def self.to_csv(options = {})
    export_read_confirmations = options[:customer].settings.approved_read_graph?
    options.delete(:customer)

   keys = KEYS
   keys += %w[nb_viewers reading_rate] if export_read_confirmations 

    special_keys = {
      author: ->(e) { e.author.name.full },
      publisher: ->(e) { (e.publisher.nil? ? "" : e.publisher.name.full) },
      pilot: ->(e) { (e.pilot.nil? ? "" : e.pilot.name.full) },
      verifiers: ->(e) { e.verifiers.map(&:name).map(&:full).join(", ") },
      approvers: ->(e) { e.approvers.map(&:name).map(&:full).join(", ") },
      confidential: lambda { |e|
        I18n.t("helpers.graphs.humanize_confidentiality.#{e.confidential}")
      },
      permalink: ->(e) { e.permalink(options[:request]) },
      url: ->(e) { e.url(options[:request]) },
      tags: ->(e) { e.tags.pluck(:label).join(",") },
      contributors: ->(e) { e.display_contributors },
      nb_events: ->(e) { e.events.count },
      parents: ->(e) { e.parents_actions.pluck(:title).join(",") },
      children_permalink: lambda { |e|
        e.children_actions.all.map do |gg|
          gg.last_active_available&.permalink(options[:request])
        end.join(",")
      },
      children_link: lambda { |e|
        e.children_actions.all.map do |gg|
          gg.last_active_available&.url(options[:request])
        end.join(",")
      },
      roles: ->(e) { e.linked_roles.pluck(:title).join(",") },
      inputs_elmnts: lambda { |e|
        e.inputs_elments_input_data.pluck(:text).join(",")
      },
      inputs_triggering: lambda { |e|
        e.inputs_elmnts.pluck(:text).join(",")
      },
      inputs_triggering_permalink: lambda { |e|
        e.triggering_permalinks.join(",")
      },
      outputs_elmnts: lambda { |e|
        e.outputs_elments_output_data.pluck(:text).join(",")
      },
      outputs_triggering: lambda { |e|
        e.outputs_elmnts.pluck(:text).join(",")
      },
      outputs_triggering_permalink: lambda { |e|
        e.triggering_permalinks("outputs").join(",")
      },
      events_links: ->(e) { e.events_links.join(",") },
      parents_permalink: lambda { |e|
        e.parents_actions.all.map do |gg|
          gg.last_active_available&.permalink(options[:request])
        end.join(",")
      },
      parents_link: lambda { |e|
        e.parents_actions.all.map do |gg|
          gg.last_active_available&.url(options[:request])
        end.join(",")
      },
      nb_risks: ->(e) { e.risks.count }
    }

    if export_read_confirmations
      special_keys[:nb_viewers] = lambda { |e|
        e.in_application? ? e.all_viewers.count : ""
      }
    end

    export_csv(all, keys, special_keys, "activerecord.attributes.graph")
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength,
  # rubocop:enable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

  def state_humanize
    ApplicationController.helpers.humanize_state(state, publish_date)
  end

  def risks_title
    risks.all.map do |r|
      r.field_value_value("title")
    end
  end

  def reading_rate
    if in_application?
      count_all_viewers = all_viewers.count
      if count_all_viewers.positive?
        (count_read_confirmations * 100 / count_all_viewers)
      else
        0
      end
    else
      ""
    end
  end

  def next_review_date
    groupgraph.review_date
  end

  def events_title
    events.all.map do |ev|
      ev.field_value_value("title")
    end
  end

  def published_at
    return action_timestamp("published") if in_application?

    ""
  end

  def changed_pilot_at
    timestamp = action_timestamp("change_pilot")
    return new_pilot_at if timestamp.blank?

    timestamp
  end

  def new_pilot_at
    action_timestamp("new_pilot")
  end

  def deactivated_at
    action_timestamp("deactivated")
  end

  def validation_sent_at
    action_timestamp("wf_started")
  end

  def breadcrumb_str
    path_str = directory.self_and_ancestors.map do |node|
      node.root? ? "" : "#{node.name.html_safe} / "
    end.join

    path_str + title
  end

  def children
    children_actions.all.map do |gg|
      gg.last_active_available&.title
    end
  end

  def events_links
    events.map do |e|
      # not using helpers since it seems that it is outdated for events.
      # TODO configure a proper way to use helpers just like risks
      # or just find a better way
      "https://#{customer.url}/improver/events/#{e.id}"
    end
  end

  def risks_links
    risks.map do |r|
      helpers = Rails.application.routes.url_helpers
      helpers.risks_risk_url(r, host: customer.url, protocol: "https")
    end
  end

  ##
  # Return contributors' name and number of comments separated with comma.
  # For example: `Paul MARTIN (3), Richard FERRAND (2), Paul COLOMD (0)`
  #
  # TODO: Move this method to the `Discussion::Discussable` concern
  #       once legacy `Contribution`s is replaced by `Discussion`s
  #
  # @note This is used for the `Contribution` column in the export
  # @return [String]
  #
  def display_contributors
    contribs = contributors.reject(&:deactivated?)
    ([author] + contribs).map do |user|
      full_name = user.name.full
      nb_of_contributions = user.contributions.where(contributable: self).count

      "#{full_name} (#{nb_of_contributions})"
    end.join(", ")
  end

  ##
  # Return true if the graph can have another version.
  # This returns false if there is already a version in the publishing process.
  #
  # @note this is a private function for `increment_version`
  #
  def check_increment_version
    res = true
    if groupgraph.graphs.where(state: Graph.unstable_states).count.positive?
      errors.add :base, :has_child
      res = false
    end
    res
  end

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  # rubocop:disable Metrics/AbcSize: Assignment Branch Condition
  # FIXME: there are some cases in which the graphs_log for the graph does
  # not exist. To prevent a 500 error in the calling method which compares dates,
  # this method will send back a date from 100 years instead of nil.
  # THIS IS A TEMP FIX.
  # We need to clarify what is a task, and what is the ordering needed.
  #
  def task_date_for(category)
    category = category.to_sym
    case category
    when :graphs_in_creation
      updated_at
    when :graphs_in_verification
      graphs_logs.last&.created_at || Time.now - 100.year
    when :graphs_in_approval
      graphs_logs.last&.created_at || Time.now - 100.year
    when :graphs_publishing_in_progress
      graphs_logs.last&.created_at || Time.now - 100.year
    when :graphs_contributable
      created_at
    when :read_confirmation
      graphs_logs.where(action: :published).last&.created_at || Time.now - 100.year
    when :graph_review
      groupgraph.remind_date.to_datetime
    end
  end
  # rubocop:enable Metrics/AbcSize: Assignment Branch Condition
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # return the suitable help for the graph
  def help
    case level
    when 1
      form_1p
    when 2
      form_2p
    when 3
      if tree
        form_decision_tree
      else
        form_3p
      end
    end
  end

  # get all the pastilles used in the graph
  def pastilles
    return nil if level != 2

    elements.collect(&:pastilles).flatten.uniq(&:pastille_setting_id)
  end

  def all_viewers
    # do 3 requests whose 2 inner join
    customer.users.where(
      deactivated: false,
      id: UsersGroup.where(group_id: viewergroup_ids).pluck(:user_id) +
                                     RolesUser.where(role_id: viewerrole_ids).pluck(:user_id) +
                                     viewer_ids
    )
  end

  # viewers of graph who marked it as read.
  def confirmed_viewers
    customer.users.where(id: read_confirmations
                             .where(user_id: all_viewers.pluck(:id))
                             .pluck(:user_id))
            .order("lastname asc")
  end

  # viewers of graph who didn't mark it as read.
  def unconfirmed_viewers
    all_viewers - confirmed_viewers
  end

  def count_read_confirmations
    read_confirmations.where(user_id: all_viewers.pluck(:id)).count
  end

  def percentage_read_confirmations
    count_all_viewers = all_viewers.count
    count_all_viewers.zero? ? 0 : (count_read_confirmations * 100 / count_all_viewers)
  end

  def toggle_auto_role_viewer(flag)
    Groupgraph.transaction do
      groupgraph.update(auto_role_viewer: flag)
      Graph.transaction do
        if flag
          add_role_element_to_viewer
        else
          viewerroles.destroy(linked_internal_roles)
        end
      end
    end
  end

  def add_role_element_to_viewer(old_roles = nil)
    return unless groupgraph.auto_role_viewer

    viewerroles << linked_internal_roles.reject { |role| viewerroles.include?(role) }

    return if old_roles.blank?

    role_to_delete = old_roles.reject { |r| linked_internal_roles.include?(r) }
    viewerroles.delete(role_to_delete)
  end

  def toggle_review(flag)
    if flag
      groupgraph.update(
        review_enable: flag,
        review_date: Date.today.next_year,
        review_reminder: Groupgraph.review_reminders[:two_week_before]
      )
    else
      groupgraph.update(review_enable: flag)
    end
  end

  def in_review_period?
    return false unless groupgraph.review_enable
    return false unless review_date_not_passed?

    case groupgraph.review_reminder
    when "one_week_before" then Date.today > groupgraph.review_date.prev_day(7)
    when "two_week_before" then Date.today > groupgraph.review_date.prev_day(14)
    when "one_month_before" then Date.today > groupgraph.review_date.prev_month(1)
    when "three_month_before" then Date.today > groupgraph.review_date.prev_month(3)
    else false
    end
  end

  def review_date_not_passed?
    Date.today < groupgraph.review_date
  end

  def complete_review(reviewer)
    return false if !in_review_period? || !groupgraph.review_enable

    Groupgraph.transaction do
      groupgraph.review_histories.create(review_date: Date.today, reviewer: reviewer)
      groupgraph.update(review_date: Date.today.next_year)
    rescue ActiveRecord::RecordInvalid
      raise ActiveRecord::Rollback
    end

    true
  end

  def last_review_date
    histories = groupgraph.review_histories
    groupgraph.review_histories.last.review_date unless histories.empty?
  end

  def steps
    steps_tab = []
    graph_steps.each do |graph_step|
      steps_tab << graph_step.set_content unless graph_step.set_content.blank?
    end
    "[#{steps_tab.join(',')}]"
  end

  def generate_uid(start_from = nil)
    # TODO: This method is repeated by all models uisng a UID.
    # It must be taken out to the concerns, at the next stage of
    # linting/refactoring. The start_from var was only used for
    # migrations, it should be removed in the refactoring.

    return unless uid.blank?

    # The UID has to be initialized before the while statement, otherwise UID is
    # blank. The first graph will be created with UID = nil and the rest of the
    # graphs will fail validations.
    self.uid = next_uid(start_from)
    self.uid = next_uid(start_from) while Graph.exists?(uid: uid)
  end

  def next_uid(start_from)
    graph_count = start_from.nil? ? Graph.count : start_from
    "#{Rails.env}-#{Time.now.to_i}-#{graph_count}"
  end

  private

  def check_version
    graph_from_base = Graph.find_by_customer_id_and_reference_and_version(customer.id, reference, version)
    return if graph_from_base.nil?

    if new_record?
      errors.add :version, :uniqueness_version
    elsif graph_from_base.id != id
      errors.add :version, :uniqueness_version_ref
    end
  end

  def check_model
    return if model.nil?

    errors.add :model_id, :not_found if Model.find_by_customer_id_and_type_and_level(customer.id, type, level).nil?
  end

  # Retrieve a scheduler (Sidekiq) job
  # FIXME: safe_load now requires that classes be explicitly white-listed.
  # However the more sound solution is to change Sidekiq for ActiveJob.
  # Furthermore, this method seems to only check if the graph is waiting for
  # publication. This should be a state in the workflow.
  # rubocop: disable Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load
  def scheduler_get_publish_job
    Sidekiq::ScheduledSet.new.select do |job|
      next unless job.item["class"] == "Sidekiq::Extensions::DelayedModel"

      ((object, method) = YAML.load(job.args[0])) &&
        object.instance_of?(Graph) && object.id == id && method == :publish
    end.at(0)
  end
  # rubocop: enable Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load

  # Add a scheduler (Sidekiq) job
  def scheduler_add_publish_job
    delay_until(publish_date, retry: false).publish if publish_date
  end

  # Delete a scheduler (Sidekiq) job
  def scheduler_del_publish_job
    scheduler_job = scheduler_get_publish_job
    scheduler_job&.delete
  end

  # return an array of all the forms used in G1P: What is G1P?
  def form_1p
    %i[external_role processus_group processus sub_processus procedure
       basket constraint_indicator control_indicator main_process_indicator]
  end

  def form_2p
    %i[internal_role external_role unit_role graph_start graph_upstream
       instruction sub_procedure macro_instruction
       collaborative_instruction graph_end graph_downstream resource
       document logical_operator related_role basket constraint_indicator
       control_indicator]
  end

  def form_3p
    %i[internal_role graph_start graph_upstream operation
       macro_operation control_operation corrective_operation graph_end
       graph_downstream resource document logical_operator related_role
       basket constraint_indicator control_indicator]
  end

  def form_decision_tree
    form_3p - %i[corrective_operation control_operation]
  end

  def action_timestamp(action)
    last_log = graphs_logs.where(action: action).last
    return "" if last_log.nil?

    last_log.updated_at.strftime("%Y-%m-%d")
  end
end
