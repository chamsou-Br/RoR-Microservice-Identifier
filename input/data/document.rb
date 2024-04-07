# frozen_string_literal: true

# == Schema Information
#
# Table name: documents
#
#  id                         :integer          not null, primary key
#  uid                        :string(255)
#  title                      :string(255)
#  url                        :string(2083)
#  reference                  :string(255)
#  version                    :string(255)
#  extension                  :string(255)
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  directory_id               :integer
#  customer_id                :integer
#  file                       :string(255)
#  author_id                  :integer
#  purpose                    :string(12000)
#  state                      :string(255)
#  domain                     :text(65535)
#  confidential               :boolean          default(FALSE)
#  parent_id                  :integer
#  groupdocument_id           :integer
#  news                       :string(765)
#  pilot_id                   :integer
#  print_footer               :string(100)
#  read_confirm_reminds_at    :datetime
#  imported_package_id        :integer
#  imported_uid               :string(255)
#  imported_groupdocument_uid :string(255)
#
# Indexes
#
#  fk_documents_groupdocument       (groupdocument_id)
#  index_documents_on_author_id     (author_id)
#  index_documents_on_customer_id   (customer_id)
#  index_documents_on_directory_id  (directory_id)
#  index_documents_on_extension     (extension)
#  index_documents_on_parent_id     (parent_id)
#  index_documents_on_reference     (reference)
#  index_documents_on_state         (state)
#  index_documents_on_title         (title)
#  index_documents_on_updated_at    (updated_at)
#

# require 'file_size_validator'
require "sidekiq/api"
class Document < ApplicationRecord
  include MediaFile
  include SearchableDocument
  include Workflow
  include Sanitizable
  include Discussion::Discussable
  include PrintableFooter
  include LinkableFieldable
  include EntityExporter

  mediafile delete_dir_if_empty: false

  sanitize_fields :domain, :news, :print_footer, :purpose, :reference, :title

  attr_accessor :confirm_read

  belongs_to :directory
  belongs_to :customer

  # @!attribute [rw] author
  #   @return [User]
  belongs_to :author, foreign_key: "author_id", class_name: "User"

  # @!attribute [rw] pilot
  #   @return [User]
  belongs_to :pilot, foreign_key: "pilot_id", class_name: "User", optional: true

  # Actors
  has_many :documents_verifiers, dependent: :destroy
  has_many :verifiers, -> { where "documents_verifiers.historized = ?", false }, through: :documents_verifiers

  has_many :documents_approvers, dependent: :destroy
  has_many :approvers, -> { where "documents_approvers.historized = ?", false }, through: :documents_approvers

  has_one :document_publisher, dependent: :destroy
  # @!attribute [rw] publisher
  #   @return [User]
  has_one :publisher, through: :document_publisher

  has_many :documents_viewers, dependent: :destroy
  has_many :viewers, through: :documents_viewers, source_type: "User"
  has_many :viewergroups, through: :documents_viewers, source_type: "Group", source: :viewer
  has_many :viewerroles, through: :documents_viewers, source_type: "Role", source: :viewer
  # /Actors

  has_many :read_confirmations, as: :process, dependent: :destroy

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  has_many :favorites, as: :favorisable, dependent: :destroy
  has_many :likers, through: :favorites, source: :user

  has_many :documents_logs, dependent: :destroy

  has_many :impactables_impacts, as: :impact, dependent: :destroy
  has_many :events, through: :impactables_impacts, source: :impactable, source_type: "Event"
  has_many :acts, through: :impactables_impacts, source: :impactable, source_type: "Act"
  has_many :risks, through: :impactables_impacts, source: :impactable, source_type: "Risk"

  belongs_to :groupdocument, optional: true

  # FIXME: This `parent/child` semantic seems to be the way to do the
  #        versioning of documents before `Groupdocument`s was introduced.
  #        This does not seem to be used anymore,
  has_one :child, class_name: "Document", foreign_key: "parent_id"
  belongs_to :parent, class_name: "Document", optional: true

  validates :title, presence: true,
                    uniqueness: { is: true, scope: %i[customer_id version] }
  validates :reference, presence: true,
                        uniqueness: { is: true, scope: %i[customer_id version] }
  validates :author, presence: true
  validates :extension, length: { in: 2..6 }, allow_nil: true
  validates :directory, presence: true
  validates :customer, presence: true
  validates :state, inclusion: { in: %w[new verificationInProgress approvalInProgress
                                        approved applicable deactivated archived] }
  validate :url_xor_file
  validates :purpose, length: { maximum: 12_000 }
  validates :domain, length: { maximum: 65_535 }

  # @!attribute [rw] news
  #   @return [String]
  validates :news, length: { maximum: 765 }, allow_nil: true

  validates :url, length: { maximum: 2083 }

  scope :ordered, -> { order("title ASC") }
  scope :applicable, -> { where(state: :applicable) }

  before_validation do |document|
    if document.file.path.nil?
      document.extension = nil
    else
      extension = File.extname(URI.parse(document.actual_url).path).gsub(/^./, "")
      document.extension = extension unless extension.empty?
    end
  end

  before_create do |document|
    # Pour un nouveau document (le premier d'un groupdocument), il faut créer le groupdocument
    document.groupdocument = Groupdocument.create(customer_id: document.customer_id) if document.groupdocument_id.nil?
  end

  before_create :generate_uid

  def all_versions
    groupdocument.documents
  end

  # TODO: there is a serializer already at app/serializers/document_serializer.rb
  # but with too much information. Need to do a manual serialiazer as other
  # parts (ElasticSearch) count on the default as_json method, so it cannot be
  # overwritten.
  def serialize_this
    as_json(only: %i[id title extension url file domain])
  end

  def self.domain_url_extension
    %w[com tk de net uk org cn info nl ru eu br au fr it ar pl biz ca us ch es co be jp se in dk at kr]
  end

  # rubocop:disable Naming/MethodName, Naming/PredicateName
  def is_domainURL?
    Document.domain_url_extension.include? actual_extension
  end

  def is_current_state(possible_state)
    state == possible_state
  end
  # rubocop:enable Naming/MethodName, Naming/PredicateName

  # file url independently from mode (url or fileupload)
  def actual_url
    absolute_url
  end

  def actual_extension
    actual_url.split(".").last.downcase
  end

  def html_filename
    if file.nil? || file.blank?
      actual_url
    else
      file.to_s[(file.to_s.rindex("/") + 1)..file.to_s.length]
    end
  end

  ##
  # Return all prossible state a document can be in
  #
  # FIXME : This is a duplication of the above `validates :state, inclusion:` values
  #
  def self.states
    %w[new verificationInProgress approvalInProgress approved applicable deactivated archived]
  end

  ##
  # Return states in which a document is not stable, in the publishing progress.
  #
  # @note This is used to check if a new version of the document can be created.
  #       A document can only have one new version that is in preparation.
  #       (several stable versions but only one unstable)
  # @note This is exactly the same rule with documents
  #
  def self.unstable_states
    %w[new verificationInProgress approvalInProgress approved]
  end

  def in_edition?
    state == "new"
  end

  def in_verification?
    state == "verificationInProgress"
  end

  def in_approval?
    state == "approvalInProgress"
  end

  def in_application?
    state == "applicable"
  end

  def in_publication?
    (state == "approved") && scheduler_get_publish_job.nil?
  end

  def in_scheduled_publication?
    (state == "approved") && !scheduler_get_publish_job.nil?
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

  def action_date(action)
    documents_logs.where(action: action).last
  end

  def ancestors
    current_doc = self
    array_of_ancestors = []
    until current_doc.parent.nil?
      array_of_ancestors << current_doc.parent
      current_doc = current_doc.parent
    end
    array_of_ancestors
  end

  def versions_list
    groupdocument.documents.order(created_at: "DESC")
  end

  def absolute_url
    if url.blank?
      relative_file_url
    else
      url
    end
  end

  def to_json(options = {})
    super(methods: DocumentPolicy.viewable?(options[:current_user], self) ? :absolute_url : nil)
  end

  def delete_verifier(user)
    documents_verifiers.delete(documents_verifiers.where(verifier_id: user, historized: false))
    verifiers.reload
  end

  def delete_approver(user)
    documents_approvers.delete(documents_approvers.where(approver_id: user, historized: false))
  end

  # rubocop:disable Naming/PredicateName
  def is_verified?
    documents_verifiers.count.positive? && documents_verifiers.find_by_verified_and_historized(false, false).nil?
  end

  def is_approved?
    documents_approvers.count.positive? && documents_approvers.find_by_approved_and_historized(false, false).nil?
  end

  def is_published?
    !document_publisher.nil? && document_publisher.published
  end
  # rubocop:enable Naming/PredicateName

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def reset_state(sender)
    if in_verification? || in_approval?
      verifiers.each do |user|
        row = documents_verifiers.where(verifier_id: user.id, historized: false).first
        row.historized = true
        documents_verifiers.create(verifier_id: user.id) if row.save
      end
      verifiers.reload
    end
    if in_approval?
      approvers.each do |user|
        row = documents_approvers.where(approver_id: user.id, historized: false).first
        row.historized = true
        documents_approvers.create(approver_id: user.id) if row.save
      end
      approvers.reload
    end
    old_state = state
    self.state = "new"
    notify_state_change(sender, old_state, state)
    save
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  # Retrieve a scheduler (Sidekiq) job
  # FIXME: safe_load now requires that classes be explicitly white-listed.
  # However the more sound solution is to change Sidekiq for ActiveJob.
  # Furthermore, this method seems to only check if the document is waiting
  # for publication. This should be a state in the workflow instead.
  # rubocop: disable Security/YAMLLoad: Prefer using YAML.safe_load over YAML.load
  def scheduler_get_publish_job
    Sidekiq::ScheduledSet.new.select do |job|
      next unless job.item["class"] == "Sidekiq::Extensions::DelayedModel"

      ((object, method) = YAML.load(job.args[0])) &&
        object.instance_of?(Document) &&
        object.id == id && method == :publish
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

  def publish_date
    state == "approved" && !document_publisher.nil? ? document_publisher.publish_date : nil
  end

  # Return a hash where each pair is composed by
  # [key] a iso8601 publication date
  # [val] an array containing each document
  def self.publish_agenda(customer, filter_id)
    documents = {}
    # customer.documents.all(:conditions => 'state = "approved"').each do |document|
    customer.documents.where(state: "approved").each do |document|
      next if document.publish_date.nil? || (document.id == filter_id)

      date = document.publish_date
      next unless date

      iso = date.iso8601
      documents[iso] ||= []
      documents[iso] << document.as_json(only: %i[id title])
    end
    documents
  end

  # Called level to be consistent with graph export
  def level
    url.blank? ? "uploaded" : "link"
  end

  #
  # Publish this document optionally as the given `admin`
  #
  # @param [User, nil] admin
  # @return [Boolean] `true` if the document was published and `false` otherwise
  #
  # rubocop:disable Metrics/MethodLength
  def publish(admin = nil)
    document_publisher.published = true
    if document_publisher.save
      scheduler_del_publish_job # in case Sidekiq fails to remove it
      comment = if admin.nil?
                  nil
                else
                  I18n.t(
                    "controllers.documents.admin_publish.published_comment",
                    admin: admin.name.full,
                    user: publisher.name.full
                  )
                end
      publisher = admin.nil? ? self.publisher : admin

      DocumentsLog.create(
        document_id: id,
        user_id: publisher.id,
        action: "published_by",
        comment: comment
      )
      next_state publisher
      true
    else
      false
    end
  end
  # rubocop:enable Metrics/MethodLength

  def publish_on(date)
    scheduler_del_publish_job
    document_publisher.publish_date = date
    if document_publisher.save
      !scheduler_add_publish_job.nil?
    else
      false
    end
  end

  def check_duplicable
    res = true
    unless in_application?
      errors.add :base, :cant_duplicate
      res = false
    end
    unless child.nil?
      errors.add :base, :has_child
      res = false
    end
    res
  end

  ##
  # Increment the version of the document by duplicating the current one
  # and keeping it tide to the groupdocument, which contains all document's versions.
  #
  # The new version is created only if there is no other unstable version of the document
  # (that is in the publishing process).
  #
  # rubocop:disable Metrics/MethodLength
  def increment_version(next_version)
    if check_increment_version
      document_duplicated = dup # duplicate the current attributes
      document_duplicated.file = file unless file.blank?
      document_duplicated.attributes = {
        version: next_version,
        state: "new",
        news: nil,
        author: groupdocument.last_available.author
      }
      document_duplicated.parent = self
      document_duplicated.uid = nil
      document_duplicated.imported_package_id = nil
      document_duplicated.imported_uid = nil
      document_duplicated.imported_groupdocument_uid = nil
      if document_duplicated.save
        DocumentsViewer.duplicate_for(document_duplicated)
        DocumentsVerifier.duplicate_for(document_duplicated)
        DocumentsApprover.duplicate_for(document_duplicated)
        DocumentPublisher.duplicate_for(document_duplicated)
        Tagging.duplicate_for(document_duplicated)
        return true
      end
    end
    false
  end

  ##
  # Return true if the document can have another version.
  # This returns false if there is already a version in the publishing process.
  #
  # @note this is a private function for `increment_version`
  #
  def check_increment_version
    res = true
    if groupdocument.documents.where(state: Document.unstable_states).count.positive?
      errors.add :base, :has_child
      res = false
    end
    res
  end

  #
  # Update the author of this document to be the `current_user`'s fellow user
  # matching the given `author_id` that is an active power user
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

    DocumentsLog.create(
      document_id: id,
      user_id: author_id,
      action: "change_author",
      comment: I18n.t("helpers.documents.humanize_log.change_author_by",
                      author: new_author.name.full,
                      admin: current_user.name.full)
    )

    true
  end
  # rubocop:enable Metrics/MethodLength

  #
  # Updates the `pilot` of the document
  #
  # @param [User] current_user
  # @param [Integer, String] pilot_id of the new pilot
  #
  # @return [Boolean] `true` if the pilot was updated or `false` otherwise
  #
  def change_pilot(current_user, pilot_id)
    new_pilot = pilot.nil?

    self.pilot = current_user.customer.users.find(pilot_id)

    return false unless save

    # Notify the new pilot that they are now the pilot of this entity
    NewNotification.create_and_deliver(customer: current_user.customer,
                                       category: :change_pilot,
                                       from: current_user,
                                       to: pilot,
                                       entity: self)

    # Log the change of pilot for this entity
    DocumentsLog.create(
      document_id: id,
      user_id: pilot_id,
      action: new_pilot ? "new_pilot" : "change_pilot",
      comment: I18n.t("helpers.graphs.humanize_log.#{new_pilot ? 'set' : 'change'}_pilot_by",
                      pilot: pilot.name.full,
                      user: current_user.name.full)
    )

    true
  end

  def comment_wf_max_length
    765
  end

  # TODO: breaking extra long SQL strings I leave for a second phase, where
  # tests are writen.
  def linked_graphs
    customer.graphs.where.not(state: %w[deactivated archived])
            .includes(:elements).where(
              "(elements.shape=:shape OR elements.model_type=:model_type)
              AND elements.model_id=:model_id",
              shape: "Document", model_type: "Groupdocument",
              model_id: groupdocument_id
            )
            .references(:elements)
  end

  def linked_graphs_links
    linked_graphs.map do |lg|
      Rails.application.routes.url_helpers.url_for(
        controller: :graphs,
        action: :show,
        id: lg.id,
        host: customer.url,
        protocol: "https"
      )
    end
  end

  def events_title
    events.all.map do |ev|
      ev.field_value_value("title")
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

  def risks_title
    risks.all.map do |r|
      r.field_value_value("title")
    end
  end

  def risks_links
    risks.map do |r|
      helpers = Rails.application.routes.url_helpers
      helpers.risks_risk_url(r, host: customer.url, protocol: "https")
    end
  end

  # rubocop:disable Naming/PredicateName
  def has_deactivated_actors?
    involved_users = (verifiers.to_a + approvers.to_a + [publisher]).uniq
    involved_users.any? { |user| user&.deactivated? }
  end
  # rubocop:enable Naming/PredicateName

  def permalink(request, protocol = "")
    proto = protocol == "" ? request.protocol : protocol
    absolute = "#{proto}#{request.host}"
    absolute += ":#{Settings.server.port}" unless Settings.server.port.nil?
    absolute += "/groupdocuments/#{groupdocument.id}/show_properties"
    absolute
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


  KEYS = %w[
    title reference level state version purpose domain author
    publisher pilot changed_pilot_at validation_sent_at verifiers approvers
    confidential created_at updated_at published_at deactivated_at permalink
    url tags news linked_graphs linked_graphs_links nb_events events_title
    events_links nb_risks risks_title risks_links breadcrumb_str
  ]

  def self.default_export_keys(options = {})

    export_read_confirmations = options[:customer].settings.approved_read_document?

    keys = KEYS
    keys += %w[nb_viewers reading_rate] if export_read_confirmations
    special_keys = {
    state: ->(e) { I18n.t(e.state, scope: "activerecord.attributes.document.states") },
    author: ->(e) { e.author.nil? ? "" : e.author.name.full },
    publisher: ->(e) { e.publisher.nil? ? "" : e.publisher.name.full },
    pilot: ->(e) { e.pilot.nil? ? "" : e.pilot.name.full },
    verifiers: ->(e) { e.verifiers.map(&:name).map(&:full).join(",") },
    approvers: ->(e) { e.approvers.map(&:name).map(&:full).join(",") },
    confidential: lambda { |e|
      I18n.t("helpers.documents.humanize_confidentiality.#{e.confidential}")
    },
    url: ->(e) { e.url_export },
    permalink: ->(e) { e.permalink(options[:request], "https://") },
    tags: ->(e) { e.tags.pluck(:label).join(",") },
    linked_graphs: ->(e) { e.linked_graphs.map(&:title).join(",") },
    nb_events: ->(e) { e.events.count },
    nb_risks: ->(e) { e.risks.count }
  }

  if export_read_confirmations
    special_keys[:nb_viewers] = lambda { |e|
      e.in_application? ? e.all_viewers.count : ""
    }
  end

  [keys, special_keys]

  end

  # rubocop:disable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def self.to_csv(options = {})
  
    export_read_confirmations = options[:customer].settings.approved_read_document?

    keys = KEYS
    keys += %w[nb_viewers reading_rate] if export_read_confirmations
    special_keys = {
      state: ->(e) { I18n.t(e.state, scope: "activerecord.attributes.document.states") },
      author: ->(e) { e.author.nil? ? "" : e.author.name.full },
      publisher: ->(e) { e.publisher.nil? ? "" : e.publisher.name.full },
      pilot: ->(e) { e.pilot.nil? ? "" : e.pilot.name.full },
      verifiers: ->(e) { e.verifiers.map(&:name).map(&:full).join(",") },
      approvers: ->(e) { e.approvers.map(&:name).map(&:full).join(",") },
      confidential: lambda { |e|
        I18n.t("helpers.documents.humanize_confidentiality.#{e.confidential}")
      },
      url: ->(e) { e.url_export },
      permalink: ->(e) { e.permalink(options[:request], "https://") },
      tags: ->(e) { e.tags.pluck(:label).join(",") },
      linked_graphs: ->(e) { e.linked_graphs.map(&:title).join(",") },
      nb_events: ->(e) { e.events.count },
      nb_risks: ->(e) { e.risks.count }
    }

    if export_read_confirmations
      special_keys[:nb_viewers] = lambda { |e|
        e.in_application? ? e.all_viewers.count : ""
      }
    end

    export_csv(all, keys, special_keys, "activerecord.attributes.document")
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def url_export
    if file.blank?
      absolute_url
    else Rails.application.routes.url_helpers.url_for(
      controller: :documents,
      action: :download,
      file_name: html_filename,
      id: id,
      host: customer.url,
      protocol: "https"
    )
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

  # rubocop:disable Metrics/AbcSize: Assignment Branch Condition size
  # TODO: Look at comments for the same method in graph.rb
  #
  def task_date_for(category)
    category = category.to_sym
    case category
    when :documents_in_creation
      updated_at
    when :documents_in_verification
      documents_logs.last&.created_at || Time.now - 100.year
    when :documents_in_approval
      documents_logs.last&.created_at || Time.now - 100.year
    when :documents_publishing_in_progress
      documents_logs.last&.created_at || Time.now - 100.year
    when :read_confirmation
      documents_logs.where(action: :published).last&.created_at || Time.now - 100.year
    end
  end
  # rubocop:enable Metrics/AbcSize: Assignment Branch Condition size
  # rubocop:enable Metrics/PerceivedComplexity, Metrics/CyclomaticComplexity

  def count_read_confirmations
    read_confirmations.where(user_id: all_viewers.pluck(:id)).count
  end

  def all_viewers
    # do 3 requests whose 2 inner join
    customer.users.where(id: UsersGroup.where(group_id: viewergroup_ids).pluck(:user_id) +
                             RolesUser.where(role_id: viewerrole_ids).pluck(:user_id) +
                             viewer_ids)
  end

  # viewers of document who didn't mark it as read.
  def unconfirmed_viewers
    all_viewers - confirmed_viewers
  end

  # viewers of document who marked it as read.
  def confirmed_viewers
    customer.users.where(id: read_confirmations.where(user_id: all_viewers.pluck(:id)).pluck(:user_id))
            .order("lastname asc")
  end

  def percentage_read_confirmations
    count_all_viewers = all_viewers.count
    count_all_viewers.zero? ? 0 : (count_read_confirmations * 100 / count_all_viewers)
  end

  def generate_uid(start_from = nil)
    # TODO: Look at comments for the same method in graph.rb
    return unless uid.blank?

    # The UID has to be initialized before the while statement, otherwise UID is
    # blank. The first graph will be created with UID = nil and the rest of the
    # graph will fail validations.
    self.uid = next_uid(start_from)
    self.uid = next_uid(start_from) while Document.exists?(uid: uid)
  end

  def next_uid(start_from)
    # TODO: Look at comments for the same method in graph.rb
    graph_count = start_from.nil? ? Document.count : start_from
    "#{Rails.env}-#{Time.now.to_i}-#{graph_count}"
  end

  private

  # This method verifies that a document is not given both a url and a file.
  # If both are given, the document is not valid. File is an upload of
  # Carrierwave, and when checking if the file is blank?, it seems to verify
  # the physical existence of the file. So even if the fields are filled in,
  # the validation will fail.
  #
  # This does not seem to be the correct place for this check.
  def url_xor_file
    return if errors[:file].any?

    errors.add :base, :no_file unless url.blank? ^ file.blank?
  end

  def action_timestamp(action)
    last_log = documents_logs.where(action: action).last
    return "" if last_log.nil?

    last_log.updated_at.strftime("%Y-%m-%d")
  end
end
