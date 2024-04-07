# frozen_string_literal: true

# == Schema Information
#
# Table name: events
#
#  id                 :integer          not null, primary key
#  occurrence_at      :date
#  customer_id        :integer
#  author_id          :integer
#  owner_id           :integer
#  criticality_id     :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  state              :integer
#  reference          :string(255)
#  analysis           :text(65535)
#  event_type_id      :integer
#  consequence        :string(765)
#  cost               :string(765)
#  closed_at          :date
#  internal_reference :string(255)
#
# Indexes
#
#  index_events_on_author_id      (author_id)
#  index_events_on_created_at     (created_at)
#  index_events_on_customer_id    (customer_id)
#  index_events_on_event_type_id  (event_type_id)
#  index_events_on_owner_id       (owner_id)
#  index_events_on_state          (state)
#  index_events_on_updated_at     (updated_at)
#

# TODO: Refactor and shrink class, seems to duplicate code like Act and Audit
class Event < ApplicationRecord
  # TODO: this accessor does not seem to be used.
  attr_accessor :create_audit_event

  include ActiveModel::Validations
  include Rails.application.routes.url_helpers
  include Trackable

  # Elasticsearch
  include SearchableEvent

  # Temporarily module based on Contributable, but changed to deal with actors
  include EventContributable

  include EventStateMachine
  # Include relations and behaviors Event needs from form fields, field items
  # and field values
  include FieldableEntity
  include CommonAssociations
  include Discussion::Discussable

  # IAM services
  # The introduction of these two modules changes the access of
  # responsibilities from event attributes and associations to the IAM
  # services/actors. These changes have to ripple throughout the app.
  #
  include IamEntitySetup
  include IamApiMethods

  # will paginate default per page
  self.per_page = 15

  belongs_to :customer

  # TODO: AFAIR these associations are to be deleted.
  belongs_to :criticality, class_name: "CriticalitySetting", optional: true
  alias_attribute :event_criticality, :criticality
  belongs_to :event_type, class_name: "EventTypeSetting", optional: true
  alias_attribute :type_id, :event_type_id

  has_many :new_notifications, as: :entity, dependent: :destroy

  has_many :event_causes, dependent: :destroy
  has_many :causes, through: :event_causes
  has_many :event_domains, dependent: :destroy
  has_many :domains, through: :event_domains

  has_many :acts_event, dependent: :destroy
  has_many :acts, through: :acts_event

  has_many :impactables_impacts, as: :impactable, dependent: :destroy
  has_many :graphs_impacts, through: :impactables_impacts, source: :impact,
                            source_type: "Graph"
  has_many :documents_impacts, through: :impactables_impacts, source: :impact,
                               source_type: "Document"

  has_many :timeline_items, dependent: :destroy, class_name: "TimelineEvent"

  has_many :event_attachments, dependent: :destroy
  has_many :attachments, foreign_key: "event_id", class_name: "EventAttachment"
  accepts_nested_attributes_for :attachments, allow_destroy: true

  has_many :custom_properties, foreign_key: "event_id",
                               class_name: "EventCustomProperty"

  # TODO: Associations to delete, when cim_responses are correctly dealt with.
  has_many :events_continuous_improvement_managers, dependent: :destroy
  has_many :continuous_improvement_managers,
           through: :events_continuous_improvement_managers,
           after_add: :mark_dirty_cim_ids,
           after_remove: :mark_dirty_cim_ids

  alias_attribute :cims_responses, :events_continuous_improvement_managers

  has_many :event_validators, dependent: :destroy

  # `orig_validators` refers to the association for validators in the original
  # schema to store validator responsibilities. The method `validators` now
  # refers to actors in the IAM service.
  has_many :orig_validators, through: :event_validators,
                             primary_key: :validator_id,
                             after_add: :mark_dirty_validator_ids,
                             after_remove: :mark_dirty_validator_ids
  alias_attribute :validator_ids, :orig_validator_ids

  ## Setting up a new join between audit_like entities and events
  # Deprecated associations
  has_many :audit_events, dependent: :destroy
  has_many :audits, through: :audit_events
  has_many :audit_element_subject_audit_events, through: :audit_events
  # New version of association
  belongs_to :audit_like, polymorphic: true, optional: true
  has_many :audit_like_events
  has_many :audits,
           through: :audit_like_events,
           source: :audit_like, source_type: "Audit"
  has_many :audit_elements,
           through: :audit_like_events,
           source: :audit_like, source_type: "AuditElement"
  ## End setting up join between audit_like entities and events

  enum state: { under_analysis: 0,
                pending_approval: 1,
                completed: 2,
                closed: 3,
                in_creation: 4,
                pending_closure: 5,
                pending_forced_closure: 6 }

  validate :required_desc_fields?, if: -> { state == "under_analysis" },
                                   on: :create

  validates :state, presence: true
  validates :analysis, length: { maximum: 65_535 }
  validates :consequence, length: { maximum: 765 }
  validates :cost, length: { maximum: 765 }

  # TODO: this validation needs to be done using fieldable_values now that the
  # attribute title is being deleted..
  # This validations should reflect the requirement for `title` in form fields.
  # validates :title, length: { maximum: 250 }
  # validates :title, presence: true

  validates :reference, length: { maximum: 50 }
  validates :internal_reference,
            uniqueness: { is: true, scope: [:customer_id] },
            length: { maximum: 20 }

  # This validation needs to move (or probably already exists) to the IAM
  # service. Left for now as there is extra logic for the validation, which
  # needs to be propagated.
  #
  validate :cims_presence,
           if: proc { |e|
                 e.customer&.settings&.continuous_improvement_active == true
               },
           on: %i[create update]

  # This scope preloads user records associated to events
  scope :with_preloaded_actors, lambda {
    preload(:actors, :orig_contributors, :continuous_improvement_managers,
            :event_validators, :events_continuous_improvement_managers,
            :orig_validators)
  }

  # Scope used by GraphQL for the list page
  scope :not_in_creation, -> { where.not(state: Event.states[:in_creation]) }

  # The events that have `user` as an actor.
  scope :with_involved_user, lambda { |user|
    all_ids = Actor.where(responsible: user, affiliation_type: "Event")
                   .pluck(:affiliation_id).uniq

    # Having to check this condition is bizarre. However, after some thought, I
    # can understand. Responsibilities are not deleted when certain settings
    # and options are switched on and off. So these responsibilities linger and
    # if the condition there is not tested, cim users would be returned even if
    # the customer has the cim option off.  #3300
    # TODO: refactor
    #
    if user.customer.settings&.continuous_improvement_active?
      Event.where(id: all_ids)
    else
      cim_ids = Actor.where(responsible: user,
                            affiliation_type: "Event", responsibility: "cim")
                     .pluck(:affiliation_id).uniq
      Event.where(id: all_ids - cim_ids)
    end
  }

  scope :with_involved__old_user, lambda { |user|
    events = left_outer_joins(:contributables_contributors,
                              :event_validators,
                              :events_continuous_improvement_managers)
             .references(:contributables_contributors,
                         :event_validators,
                         :events_continuous_improvement_managers)
             .distinct

    result = events.where(owner: user)
                   .or(events.where(author: user))
                   .or(events.where(event_validators: { validator: user }))
                   .or(events.where(contributables_contributors: {
                                      contributor: user
                                    }))

    if user.customer.settings&.continuous_improvement_active?
      result.or(events.where(events_continuous_improvement_managers: {
                               continuous_improvement_manager: user
                             }))
    else
      result
    end
  }

  # TODO: Remove this scope once the legacy timeline code has been removed
  # / refactored.
  scope :with_preloaded_timeline_authors, lambda {
    preload(timeline_items: :author)
  }

  def validate_all_fields
    required_fields?("description")
    required_fields?("analysis")
    required_fields?("action_plan")
  end

  # Dynamic creation of methods defining an accessor for deleted attributes.
  # TODO: Is this efficient? Do not know yet. More research is needed.
  #
  %i[description title].each do |attr|
    define_method attr do
      field_value_value(attr.to_s)
    end
  end

  #
  # Returns a normalized JSON version of this entity with form fields flattened
  # as Symbol => field value pairs
  #
  # @note This method relies on a number of relations and may require some
  #    query optimization when fetching numerous entities of this type.
  #
  # @param [User] User whose responsibilities in this event we are aggregating
  #
  # @return [Hash{Symbol, String => Hash, String}]
  #
  # @deprecated This is used for listing events in the legacy Improver V1
  #
  def event_hashed(current_user)
    {
      id: id,
      state: state,
      closed_at: closed_at,
      internal_reference: internal_reference,
      involved_responsibilities: roles_of(current_user)
    }.merge(field_value_hash)
  end

  # This return type of this method follows the graphql type: InvolvablesRoles.
  #

  # Returns an array of hashes, each hash with two keys: responsibility and
  # users. `responsibility` is a string. The possible responsibilities of an
  # event are:
  # - `event_author`
  # - `event_cim`
  # - `event_contributor`
  # - `event_owner`
  # - `event_validator`
  # users is an array of user objects, JSON_serialized. Except for the owner,
  # an object will be included only when such user is the current_user.
  # The owner object will always be included.
  #
  # If the provided user is **not** involved with this event as a given
  # responsibility,
  # the hash for that responsibility is omitted from the result entirely.
  #
  # @note This method relies on relations `author`,
  #   `continuous_improvement_managers`, `contributors`, `owner` and
  #   `validators` relations which will incur additional queries if said
  #   relations are not preloaded.
  #
  # @param [User] User whose responsibilities in this event we wish to know
  #
  # @return [Array<Hash{Symbol => String, Array<Hash>}>]
  #
  # @example
  #   # Given an event `evt` to which the user `usr` is a contributor
  #   roles = evt.roles_of(usr)
  #
  #   # Result
  #   [
  #     { responsibility: 'event_contributor', users: [{...}] }, # JSON of `usr`
  #     { responsibility: 'event_owner', users: [{...}] }, # JSON of `evt.owner`
  #   ]
  #
  # @todo Extract the responsibilities hash returned into its own plain Ruby
  #   class for better OO-style practices.
  #
  # @deprecated This is used when listing events in the legacy Improver V1
  #
  def roles_of(user)
    # Created a serialized version of the user as said serialization may be used
    # more than once
    serialized_user = user.serialize_this.deep_symbolize_keys

    [
      { responsibility: "event_author",
        users: [user == author ? serialized_user : nil] },
      { responsibility: "event_cim",
        users: [managed_by?(user) ? serialized_user : nil] },
      { responsibility: "event_contributor",
        users: [involves_contributor?(user) ? serialized_user : nil] },
      { responsibility: "event_owner",
        users: [owner.serialize_this.deep_symbolize_keys] },
      { responsibility: "event_validator",
        users: [involves_validator?(user) ? serialized_user : nil] }
    ].select { |r| r[:users].any? }
  end

  #
  # Is the provided user one of the continuous improvement managers for this
  # event?
  #
  # @note This method relies on the `continuous_improvement_managers` relation
  #   which may incur additional queries if said relation is not preloaded.
  #
  # @param [User] User whose involvement as a CIM we wish to confirm
  #
  # @return [Boolean]
  #
  def managed_by?(user)
    cim?(user)
  end

  #
  # Is the provided user a validator of this event?
  #
  # @note This method relies on the `validators` relation which may incur
  #   additional queries if said relation is not preloaded.
  #
  # @param [User] User whose involvement as a validator we wish to confirm
  #
  # @return [Boolean]
  #
  def involves_validator?(user)
    validators.include?(user)
  end

  def notification_roles_for(user)
    roles = []
    roles << :owner if owner == user
    roles << :author if author == user
    roles << :cim if managed_by?(user)
    roles << :validator if involves_validator?(user)
    roles << :contributor if involves_contributor?(user)
    roles
  end

  # TODO: method to be replaced by `responsibility?` in the IAM service
  def role?(user)
    owner == user || author == user || user.improver_admin? ||
      user.contributor_to?(self) || user.cim_of?(self) ||
      involves_validator?(user)
  end

  # Attribute change tracking currently exists for attribute, associations and
  # fieldables. Actors are a different type of object, so we need to explicitly
  # track these changes. With these two methods, we mark the actors we want to
  # track.
  # NOTE: Tracking, logging and notifications will benefit from a refactor when
  # the time comes.
  #
  def actors_to_track
    %w[cim validator contributor]
  end

  def actor_to_track
    %w[owner]
  end

  # TODO: These two methods are used for saving the notification changes with
  # the changes incurred in these fields. Hmm.
  # TODO: verify if this method can be deleted or if there is extra logic to
  # consider.
  # Method used in app/controllers/concerns/improver_notifications.rb in the
  # `log_action` method.
  #
  def many_associations_to_track
    # `validator_ids` and `contributor_ids` are no longer associations,
    # validators and contributors are now stored as actors. These are tracked
    # separately, so eventually even the cim association here will be deleted.
    # Tracking of attributes and associations will have to be revised for the
    # timeline (4.2.0) and notifications (4.1.0).
    #
    %w[continuous_improvement_manager_ids]
  end

  # TODO: Attributes that correspond to fields and are deleted can be moved to
  # the `fields_to_track` method.
  # TODO: there are no tests that actually check that these are attributes of
  # the event. Tests seem to pass when this array has attributes that have been
  # deleted from the model.
  #
  def attributes_to_track
    %w[state closed_at analysis consequence cost occurrence_at reference]
  end

  # Returns a hash of field names to track mapped to legacy timeline item key
  # names.
  #
  # FIXME: Although this definition does not belong in a method, I will create
  #   one here to keep all the definitions in one place.
  # TODO: Redesign methods *_to_track, when finished with double accounting.
  # TODO: why do we need a hash here? It seems to be used to map attributes and
  # field_values.
  # Answer: Seems like it is doing something that Rails already does (i.e.
  # resolve association names to attribute names).
  # https://gitlab.qualiproto.fr/pyx4/qualipso/-/merge_requests/3900#note_106056
  #
  def fields_to_track
    {
      acts: "act_ids",
      causes: "cause_ids",
      criticality: "criticality_id",
      description: "description",
      documents_impacts: "documents_impact_ids",
      event_attachments: "event_attachment_ids",
      event_domains: "event_domain_ids",
      event_type: "event_type_id",
      graphs_impacts: "graphs_impact_ids",
      intervention: "intervention",
      localisations: "localisation_ids",
      title: "title"
    }
  end

  #
  # Marks the `validator_ids` for the current model as dirty, for use as an
  # association callback.
  #
  def mark_dirty_validator_ids(_record)
    mark_dirty_attribute :orig_validator_ids
  end

  #
  # Marks the `:continuous_improvement_manager_ids` for the current model as
  # dirty, for use as an association callback.
  # TODO: this method is redundant, cims are marked already in the actors.
  #
  def mark_dirty_cim_ids(_record)
    mark_dirty_attribute :continuous_improvement_manager_ids
  end

  def default_contributors
    User.where(id: owner)
  end

  # TODO: wrong place to check permissions.
  def contribution_editable?
    !closed?
  end

  # TODO: not sure where is this custom_impacts method used or sourced from.
  # The same code appears in act.rb. There is also a
  # app/controllers/improver/impacts_controller.rb
  #
  def custom_impacts
    impactables_impacts.where(impact_type: nil)
  end

  def custom_impacts_ids
    custom_impacts.pluck(:id)
  end

  # Build a custom impact.
  def build_impact_from_title(title)
    impactables_impacts.build(title: title)
  end

  def task_date_for(category)
    category = category.to_sym
    case category
    when :events_under_analysis
      created_at
    when :events_pending_approval
      created_at
    when :events_contributable
      created_at
    when :events_pending_closure
      created_at
    end
  end

  # entity with continuous improvement managers and validators (wrong name).
  def cim_mode?
    # First line is checking the original way of storing responsibilities.
    # Second uses the IAM service methods.
    # TODO: implement and replace `validators?` and `cims?` in IAM service
    #
    events_continuous_improvement_managers.any? || event_validators.any? ||
      validators.any? || cims.any?
  end

  # TODO: this should be a IAM generated method
  def validators?
    validators.any?
  end

  def pending_approvals?
    (event_validators.pluck(:response) + cims_responses.pluck(:response)).include? nil
  end

  # This method resets the approvals of the validators and cim, needed when
  # the event returns to under_analysis. Leaving as-is.
  def reset_cim_and_validator_response
    events_continuous_improvement_managers.update_all(response: nil,
                                                      response_at: nil)
    event_validators.update_all(response: nil, response_at: nil)
  end

  # return the manual reference or the internal reference
  def displayed_reference
    reference = field_value_value("reference")

    reference.present? ? reference : internal_reference
  end

  ##
  # Add a process to event's impacts, which is either a graph or a document.
  #
  # @note this method is similar to `ImproverTwoHelper.process_multilinkable`
  #  by keeping both the model attribute and the form field's value up-to-date.
  #
  # @param [Graph, Document] process
  # @return [void]
  #
  def add_impact(process)
    field_name = case process.class.name
                 when "Graph" then "graphs_impacts"
                 when "Document" then "documents_impacts"
                 end

    return if send(field_name).exists?(process.id)

    # Update the related model attribute
    send(field_name).send("<<", process)

    # Update the related form field value
    form_field = form_field_entity(field_name)
    fieldable_values << FieldValue.create(form_field: form_field,
                                          entity: process)
  end

  private

  # This validation probably needs to move to the IAM service.
  def cims_presence
    # When it is a new event, there are no actor in the database, so the check
    # must be done with the instance in memory.
    #
    return if actors.map(&:responsibility).include? "cim"

    errors.add(:actors, "Cims must exist when setting is on for the customer.")
  end
end
