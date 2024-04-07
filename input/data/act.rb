# frozen_string_literal: true

# == Schema Information
#
# Table name: acts
#
#  id                  :integer          not null, primary key
#  title               :string(250)      default("")
#  description         :text(65535)
#  reference_prefix    :string(255)      default("")
#  reference           :string(255)      default("")
#  reference_suffix    :string(255)      default("")
#  act_type_id         :integer
#  estimated_start_at  :date
#  estimated_closed_at :date
#  customer_id         :integer
#  author_id           :integer
#  owner_id            :integer
#  state               :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  real_started_at     :date
#  real_closed_at      :date
#  completed_at        :date
#  achievement         :integer          default(0)
#  act_verif_type_id   :integer
#  act_eval_type_id    :integer
#  internal_reference  :string(255)
#  efficiency          :integer
#  objective           :text(65535)
#  check_result        :text(65535)
#  cost                :string(765)
#
# Indexes
#
#  index_acts_on_act_eval_type_id     (act_eval_type_id)
#  index_acts_on_act_type_id          (act_type_id)
#  index_acts_on_act_verif_type_id    (act_verif_type_id)
#  index_acts_on_author_id            (author_id)
#  index_acts_on_created_at           (created_at)
#  index_acts_on_customer_id          (customer_id)
#  index_acts_on_estimated_closed_at  (estimated_closed_at)
#  index_acts_on_owner_id             (owner_id)
#  index_acts_on_real_closed_at       (real_closed_at)
#  index_acts_on_state                (state)
#  index_acts_on_updated_at           (updated_at)
#

class Act < ApplicationRecord
  include Rails.application.routes.url_helpers
  include Trackable

  # Elasticsearch
  include SearchableAction
  include Contributable

  include ActionStateMachine
  # Include relations and behaviors Act needs from form fields, field items,
  # and field values
  include FieldableEntity
  include CommonAssociations

  # TODO: This is only for `log_action`. Methods that need this should be
  # extracted and this module removed.
  include ImproverNotifications
  include Discussion::Discussable

  # will paginate  per page
  self.per_page = 15

  belongs_to :owner, foreign_key: "owner_id", class_name: "User"
  belongs_to :author, foreign_key: "author_id", class_name: "User"
  belongs_to :customer

  # Given the relationship between action and event, the in_creation state is
  # needed until the other approves.
  # TODO:  Actions in_creation will not be listed. Verify code.
  enum state: { in_creation: 0,
                planned: 5,
                in_progress: 1,
                pending_approval: 2,
                canceled: 3,
                closed: 4 }
  enum efficiency: { not_checked: 0, efficient: 1, not_efficient: 2 }

  # TODO: These validations might end up contradicting choices in the settings,
  # as some of these event fields are also fieldables.
  validates :author, :state, :customer, :owner, presence: true
  validates :reference, length: { maximum: 50 }
  validates :objective, length: { maximum: 65_535 }
  validates :check_result, length: { maximum: 65_535 }
  validates :cost, length: { maximum: 765 }
  validate  :date_range_must_be_positive

  # This will no longer be needed when relying exclusively on form field values
  # For the time being, this reflects the requirement for `title` in predefined
  # form fields
  validates :title, presence: true, length: { maximum: 250 }

  validate :required_desc_fields?, if: -> { state == "planned" }

  validates :internal_reference,
            uniqueness: { is: true, scope: [:customer_id] },
            length: { maximum: 20 }

  has_and_belongs_to_many :action_plans
  has_many :risks,
           through: :action_plans,
           source: :plannable,
           source_type: "Risk"

  has_many :new_notifications, as: :entity, dependent: :destroy

  has_many :acts_event, dependent: :destroy
  has_many :events, through: :acts_event
  has_many :timeline_items, dependent: :destroy, class_name: "TimelineAct"
  has_many :reminders, as: :remindable

  has_many :act_attachments, dependent: :destroy
  has_many :attachments, foreign_key: "act_id", class_name: "ActAttachment"
  accepts_nested_attributes_for :attachments, allow_destroy: true

  has_many :act_domains, dependent: :destroy
  has_many :domains, through: :act_domains

  has_many :impactables_impacts, as: :impactable, dependent: :destroy

  # TODO: It looks like these associations don't need to exist.
  has_many :graphs_impacts, through: :impactables_impacts,
                            source: :impact,
                            source_type: "Graph"
  has_many :documents_impacts, through: :impactables_impacts,
                               source: :impact,
                               source_type: "Document"

  has_many :acts_validators, dependent: :destroy
  has_many :validators, through: :acts_validators,
                        after_add: :mark_dirty_validator_ids,
                        after_remove: :mark_dirty_validator_ids

  has_many :tasks
  accepts_nested_attributes_for :tasks, allow_destroy: true

  belongs_to :act_type, class_name: "ActTypeSetting", optional: true
  belongs_to :act_eval_type, class_name: "ActEvalTypeSetting", optional: true
  belongs_to :act_verif_type, class_name: "ActVerifTypeSetting", optional: true

  # Changed needed for Rails 5.2 upgrade. attr_changed? will have opposite
  # behavior. Leaving code commented as this is not tested.
  #
  # after_update :destroy_scheduled_reminders, if: :owner_id_changed?
  after_update :destroy_scheduled_reminders, if: :saved_change_to_owner_id?
  after_update :check_and_destroy_reminders_if_needed
  after_update :update_reminders
  before_destroy :destroy_scheduled_reminders

  alias_attribute :type_id, :act_type_id

  # This scope preloads user records associated to actions
  scope :with_preloaded_actors, lambda {
    preload(:author, :contributors, :owner, :validators)
  }

  # Scope used by GraphQL for the list page
  scope :not_in_creation, -> { where.not(state: Act.states[:in_creation]) }

  scope :with_involved_user, lambda { |user|
    actions = left_outer_joins(:acts_validators, :contributables_contributors)
              .references(:acts_validators, :contributables_contributors)
              .distinct

    actions.where(author: user)
           .or(actions.where(owner: user))
           .or(actions.where(acts_validators: { validator: user }))
           .or(actions.where(contributables_contributors: { contributor: user }))
  }

  # TODO: Remove this scope once the legacy timeline code has been removed
  # / refactored.
  scope :with_preloaded_timeline_authors, lambda {
    preload(timeline_items: :author)
  }

  def validate_all_fields
    required_fields?("description")
    required_fields?("evaluation")
  end

  # @deprecated This is used when listing actions in the legacy Improver V1
  def roles_of(user)
    # Created a serialized version of the user as said serialization may be used
    # more than once
    serialized_user = user.serialize_this.deep_symbolize_keys
    [
      { responsibility: "act_author",
        users: [user == author ? serialized_user : nil] },
      { responsibility: "act_contributor",
        users: [involves_contributor?(user) ? serialized_user : nil] },
      { responsibility: "act_owner",
        users: [owner.serialize_this.deep_symbolize_keys] },
      { responsibility: "act_validator",
        users: [involves_validator?(user) ? serialized_user : nil] }
    ].select { |r| r[:users].any? }
  end

  # TODO: method exactly as in event.rb. For the audit, these methods
  # should be included in a concerns file.
  #
  # Is the provided user a validator of this action?
  #
  # @note This method relies on the `validators` relation which may incur
  #   additional queries if said relation is not preloaded.
  #
  # @param user [User] whose involvement as a validator we wish to confirm
  #
  # @return [Boolean]
  #
  def involves_validator?(user)
    validators.include?(user)
  end

  # This method is someone temporary while the new roles infrastructure is put
  # in place.  It is taken from the event model.
  #
  def role?(user)
    owner == user || author == user || user.improver_admin? ||
      user.contributor_to?(self) || involves_validator?(user)
  end

  # Returns a normalized JSON version of this entity with form fields flattened
  # as Symbol => field value pairs
  #
  # @note Similar method in event.rb.
  # @note This method relies on a number of relations and may require some
  #    query optimization when fetching numerous entities of this type.
  #
  # @param current_user [User] User whose roles in this event we are aggregating
  #
  # @return [Hash{Symbol, String => Hash, String}]
  #
  # @deprecated This is used when listing actions in the legacy Improver V1
  #
  def act_hashed(current_user)
    {
      id: id,
      state: state,
      real_closed_at: real_closed_at,
      internal_reference: internal_reference,
      involved_responsibilities: roles_of(current_user)
    }.merge(field_value_hash)
  end

  def check_and_destroy_reminders_if_needed
    # Changed needed for Rails 5.2 upgrade. attr_saved? will have opposite
    # behavior. Leaving code commented as this is not tested.
    #
    # return unless state_changed?
    return unless saved_change_to_state?

    if closed_or_cancelled?
      destroy_scheduled_reminders
    elsif in_progress?
      reminder_estimated_start_at = find_reminder_for("estimated_start_at")
      reminder_estimated_start_at&.destroy
    end
  end

  # When workflow passes to cancel, if owner (or whatever role with reminders)
  # changes, if deleted
  #
  def destroy_scheduled_reminders
    # On détruit les objects et les jobs non échues
    reminders.select { |r| r.reminds_at > Date.today }.each(&:destroy)
  end

  # rubocop:disable Metrics/AbcSize
  def update_reminders
    %w[estimated_start_at estimated_closed_at].each do |attribute|
      # Changed needed for Rails 5.2 upgrade. changed? will have opposite
      # behavior. Leaving code commented as this is not tested.
      #
      # next unless changed.include?(attribute) && !find_reminder_for(attribute).nil?
      next unless saved_changes.key?(attribute) && !find_reminder_for(attribute).nil?

      current_reminder = find_reminder_for(attribute)
      if self[attribute].blank?
        current_reminder.destroy
        next
      end
      current_reminder_hash = current_reminder.attributes.slice(
        "remindable_type", "remindable_id", "reminder_type", "from_id",
        "to_id"
      )
      new_reminder = reminders.new current_reminder_hash do |r|
        r.occurs_at = self[attribute]
        r.reminds_at = self[attribute] - current_reminder.duration_in_days.days
      end

      new_reminder.perform if current_reminder.destroy && new_reminder.save
    end
  end
  # rubocop:enable Metrics/AbcSize

  # This method finds if the action is efficient by getting the field_value
  # that corresponds to the "efficient" form_field. In the field_value, finds
  # the field_item and checks that its value is equal to "efficient"
  def efficient?
    field_item_key("efficiency") == "efficient"
  end

  def progress_complete?
    field_value_value("progress") == "100"
  end

  def date_range_must_be_positive
    start_at = estimated_start_at
    closed_at = estimated_closed_at

    # Not making an assessment on validation if dates are nil
    return unless start_at && closed_at && (start_at > closed_at)

    errors.add :estimated_closed_at, :earlier_than_start
  end

  ##
  # Return form field value of `estimated_start_at` parsed as Date
  # @return [Date]
  #
  # @note this is used for TaskHelper.task_message
  #
  # TODO(#682): Remove Action attributes that have moved to form fields
  # TODO(#685): Storing dates as a DateTime object everywhere
  #
  def estimated_start_at_date
    value = field_value_value("estimated_start_at")
    return if value.nil?

    Date.parse(value)
  end

  ##
  # Return form field value of `estimated_closed_at` parsed as Date
  # @return [Date]
  #
  # @note this is used for TaskHelper.task_message
  #
  # TODO(#682): Remove Action attributes that have moved to form fields
  # TODO(#685): Storing dates as a DateTime object everywhere
  #
  def estimated_closed_at_date
    value = field_value_value("estimated_closed_at")
    return if value.nil?

    Date.parse(value)
  end

  ##
  # Overwrites the attribute accessor to use the form field value
  # @return [String]
  #
  # TODO(#682): Remove Action attributes that have moved to form fields
  #
  def estimated_start_at
    field_value_value("estimated_start_at")
  end

  ##
  # Overwrites the attribute accessor to use the form field value
  # @return [String]
  #
  # TODO(#682): Remove Action attributes that have moved to form fields
  #
  def estimated_closed_at
    field_value_value("estimated_closed_at")
  end

  # TODO: this method is redundant
  def as_json(options = {})
    super(options)
  end

  def many_associations_to_track
    %w[validator_ids contributor_ids]
  end

  # TODO: Attributes that correspond to fields can be moved to
  # `fields_to_track` in the current `development` branch.
  def attributes_to_track
    %w[state owner_id check_result description estimated_closed_at estimated_start_at
       achievement reference title]
  end

  # The implementation of these methods will be needed for when the
  # responsibilities as actors is implemented.  At the moment, these methods
  # need to exist as they are called in the concern.
  #
  def actors_to_track
    []
  end

  def actor_to_track
    []
  end

  # Returns a hash of field names to track mapped to legacy timeline item key
  # names.
  #
  # FIXME: Although this definition does not belong in a method, I will create
  #   one here to keep all the definitions in one place.
  # TODO: Redesign methods *_to_track, when finished with double accounting.
  def fields_to_track
    {
      act_attachments: "act_attachment_ids",
      act_domains: "act_domain_ids",
      act_eval_type: "act_eval_type_id",
      act_type: "act_type_id",
      act_verif_type: "act_verif_type_id",
      documents_impacts: "documents_impact_ids",
      efficiency: "efficiency_id",
      graphs_impacts: "graphs_impact_ids"
    }
  end

  #
  # Marks the `validator_ids` for the current model as dirty, for use as an
  # association callback.
  #
  def mark_dirty_validator_ids(_record)
    mark_dirty_attribute :validator_ids
  end

  # TODO: the inclusion of validator and contributor responsibilities are
  # missing. Therefore the NewNotification record does not record these
  # responsibilities.
  # The field becomes [].

  def notification_roles_for(user)
    roles = []
    roles << :owner if owner == user
    roles << :author if author == user
    roles << :validator if involves_validator?(user)
    roles << :contributor if involves_contributor?(user)
    roles
  end

  # TODO: all this method does is to get a date after a complicated assignment
  # and net of if statements. The only target seems to be the task manager on
  # right panel of the process landing page.
  def task_date_for(category)
    category = category.to_sym
    case category
    when :acts_in_creation
      created_at
    when :acts_in_progress
      created_at
    when :acts_pending_approval
      created_at
    when :acts_contributable
      created_at
    end
  end

  def reminder_category_for(attribute)
    "#{self.class.name.downcase}_#{attribute}"
  end

  def reminder_for(attribute)
    scheduled_reminder = find_reminder_for(attribute)
    scheduled_reminder.nil? ? reminders.new(reminder_type: reminder_category_for(attribute)) : scheduled_reminder
  end

  def find_reminder_for(attribute)
    reminders.where("reminder_type = ? AND reminds_at > ?", reminder_category_for(attribute), Date.today).first
  end

  def reminder_date_for(reminder_type)
    case reminder_type
    when "act_estimated_start_at"
      estimated_start_at
    when "act_estimated_closed_at"
      estimated_closed_at
    end
  end

  def reminder_schedulable_for?(type)
    case type
    when "act_estimated_start_at"
      state == "in_creation"
    when "act_estimated_closed_at"
      %w[in_creation in_progress pending_approval].include?(state)
    else
      false
    end
  end

  def closed_or_cancelled?
    closed? || canceled?
  end

  def late?
    if estimated_closed_at.nil?
      false
    else
      estimated_closed_at < Date.today && (in_creation? || in_progress? || pending_approval?)
    end
  end

  def late_by
    if late?
      (Date.today - estimated_closed_at).to_i
    else
      0
    end
  end

  def default_contributors
    User.where(id: owner)
  end

  def contribution_editable?
    !closed? && !canceled?
  end

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

  def validators_pending_responses
    acts_validators.where(response: nil)
  end

  def validators_positive_responses
    acts_validators.where.not(response: nil)
  end

  # TODO: weird method as I thought only the events had cims.
  def cim_mode?
    validator_ids.present?
  end

  # return the manual reference or the internal reference
  def displayed_reference
    reference = field_value_value("reference")
    reference.present? ? reference : internal_reference
  end
end
