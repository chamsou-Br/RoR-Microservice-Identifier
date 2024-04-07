# frozen_string_literal: true

# == Schema Information
#
# Table name: audits
#
#  id                  :integer          not null, primary key
#  title               :string(250)
#  object              :text(65535)
#  reference           :string(255)
#  synthesis           :text(65535)
#  customer_id         :integer
#  audit_type_id       :integer
#  owner_id            :integer
#  organizer_id        :integer
#  estimated_start_at  :date
#  real_start_at       :date
#  estimated_closed_at :date
#  real_closed_at      :date
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  internal_reference  :string(255)
#  state               :integer
#  real_started_at     :date
#  completed_at        :date
#
# Indexes
#
#  index_audits_on_audit_type_id        (audit_type_id)
#  index_audits_on_completed_at         (completed_at)
#  index_audits_on_created_at           (created_at)
#  index_audits_on_customer_id          (customer_id)
#  index_audits_on_estimated_closed_at  (estimated_closed_at)
#  index_audits_on_organizer_id         (organizer_id)
#  index_audits_on_owner_id             (owner_id)
#  index_audits_on_state                (state)
#  index_audits_on_updated_at           (updated_at)
#

class Audit < ApplicationRecord
  # TODO: pagination is probably no longer needed...
  # will paginate default per page
  self.per_page = 15

  include SearchableAudit
  include Contributable
  include Trackable

  include AuditStateMachine
  # Include relations and behaviors Audit needs from form fields, field items
  # and field values
  include FieldableEntity
  include CommonAssociations
  include Discussion::Discussable

  has_many :audit_elements, dependent: :destroy,
                            inverse_of: :audit,
                            after_add: :mark_dirty_audit_element_ids,
                            after_remove: :mark_dirty_audit_element_ids

  accepts_nested_attributes_for :audit_elements, allow_destroy: true

  has_many :audit_like_events, as: :audit_like
  has_many :events, through: :audit_like_events

  belongs_to :customer
  belongs_to :audit_type, class_name: "AuditTypeSetting", optional: true

  # owner = responsable
  belongs_to :owner, foreign_key: "owner_id", class_name: "User"
  # organizer = organisateur
  belongs_to :organizer, foreign_key: "organizer_id", class_name: "User"

  # TODO: not clear what are these themes or where are they used.
  # They have been replaced by field items of form fields and part of the
  # description block. It seems they are used for sorting events of the audit
  # but I do not see the link in the code.
  has_many :audit_themes, dependent: :destroy
  has_many :themes, through: :audit_themes
  alias_attribute :audit_scopes, :themes

  has_many :new_notifications, as: :entity, dependent: :destroy

  has_many :audit_attachments, dependent: :destroy
  has_many :attachments, foreign_key: "audit_id", class_name: "AuditAttachment"

  has_many :internal_auditors, through: :audit_elements
  has_many :internal_audited, through: :audit_elements
  has_many :audit_participants, through: :audit_elements
  has_many :domain_owners, through: :audit_elements

  has_many :timeline_items, dependent: :destroy, class_name: "TimelineAudit"
  has_many :reminders, as: :remindable

  enum state: { planning: 0,
                planned: 1,
                in_progress: 2,
                pending_approval: 3,
                completed: 4,
                closed: 5 }

  ## Validations
  validates :customer, :organizer, :owner, presence: true
  validates :internal_reference,
            uniqueness: { is: true, scope: [:customer_id] },
            length: { maximum: 20 }

  # This will no longer be needed when relying exclusively on form field values
  # For the time being, this reflects the requirement for `title` in predefined
  # form fields
  validates :title, presence: true, length: { maximum: 250 }
  validates :reference, length: { maximum: 255 }

  validate :required_desc_fields?

  # TODO: this check needs to happen with field values.
  validate :check_estimated_dates

  after_update :check_reminders
  before_destroy :destroy_scheduled_reminders

  # Not sure how this alias make things clear.
  # TODO: investigate where are they used. Shall they be changed?
  alias_attribute :audit_object, :object
  alias_attribute :type_id, :audit_type_id

  alias auditors internal_auditors
  alias auditees internal_audited
  alias elements audit_elements

  CATEGORIES_FOR_AUDITS = %i[audits_planning audits_planned audits_contributable
                             audits_in_progress_owner
                             audits_in_progress_auditor
                             audits_pending_approval].freeze

  # This scope preload user records associated to audits and their elements
  scope :with_preloaded_actors, lambda {
    preload(:audit_participants, :contributors, :organizer, :owner)
  }

  # This scope preloads associated audit elements records and their participants
  scope :with_preloaded_elements, lambda {
    preload(audit_elements: [:audit_participants])
  }

  scope :with_involved_user, lambda { |user|
    audits = left_outer_joins(:audit_participants, :contributables_contributors)
             .references(:audit_participants, :contributables_contributors)
             .distinct

    audits.where(owner: user)
          .or(audits.where(organizer: user))
          .or(audits.where(audit_participants: { participant_id: user.id,
                                                 participant_type: User.name }))
          .or(audits.where(contributables_contributors: { contributor: user }))
  }

  # TODO: Remove this scope once the legacy timeline code has been removed
  # / refactored.
  scope :with_preloaded_timeline_authors, lambda {
    preload(timeline_items: :author)
  }

  def validate_all_fields
    required_fields?("description")
    required_fields?("plan")
    required_fields?("synthesis")
  end

  # Returns a normalized JSON version of this entity with form fields flattened
  # as Symbol => field value pairs
  #
  # @note Similar method in event.rb.
  # @note This method relies on a number of relations and may require some
  #    query optimization when fetching numerous entities of this type.
  #
  # @param [User] User whose roles in this event we are aggregating
  #
  # @return [Hash{Symbol, String => Hash, String}]
  #
  # @deprecated This is used when listing audits in the legacy Improver V1
  #
  def audit_hashed(current_user)
    {
      id: id,
      state: state,
      real_started_at: real_started_at,
      real_closed_at: real_closed_at,
      completed_at: completed_at,
      internal_reference: internal_reference,
      involved_responsibilities: roles_of(current_user)
    }.merge(field_value_hash)
  end

  # @deprecated This is used when listing audits in the legacy Improver V1
  def roles_of(user)
    # Created a serialized version of the user as said serialization may be used
    # more than once
    serialized_user = user.serialize_this.deep_symbolize_keys
    [
      { responsibility: "audit_organizer",
        users: [user == organizer ? serialized_user : nil] },
      { responsibility: "audit_contributor",
        users: [involves_contributor?(user) ? serialized_user : nil] },
      { responsibility: "audit_owner",
        users: [owner.serialize_this.deep_symbolize_keys] },
      { responsibility: "auditor",
        users: [includes_auditor?(user) ? serialized_user : nil] },
      { responsibility: "auditee",
        users: [includes_auditee?(user) ? serialized_user : nil] },
      { responsibility: "domain_owner",
        users: [includes_domain_owner?(user) ? serialized_user : nil] }
    ].select { |r| r[:users].any? }
  end

  def role_in?(user)
    user == organizer || user == owner ||
      involves_contributor?(user) ||
      audit_participants
        .where(participant_type: "User", participant_id: user.id)
        .exists?
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

  # Adds `earlier_than_start` error if `estimated_closed_at` is before
  # `estimated_start_at`
  def check_estimated_dates
    return unless (estimated_start_at && estimated_closed_at) && (estimated_closed_at < estimated_start_at)

    errors.add(:estimated_closed_at, :earlier_than_start)
  end

  def check_real_started_date(start_date)
    return true unless start_date.nil?

    errors.add(:real_started_at, :must_be_present)
    false
  end

  # TODO: not used but not sure why was needed. Perhaps for listing actions of
  # events in the audit show page?
  def uniq_acts
    return [] if events.empty?

    events.to_a.sum(&:acts).uniq
  end

  def notification_roles_for(user)
    roles = []
    roles << :owner if owner == user
    roles << :organizer if organizer == user
    roles << :contributor if contributors.include?(user)
    roles << :auditor if includes_auditor?(user)
    # TODO: include these roles in the translation to be able to use them.
    # roles << :auditee if internal_audited.include?(user)
    # roles << :domain_owner if domain_responsibles.include?(user)
    roles << :audited if includes_auditee?(user)
    roles << :domain_responsible if includes_domain_owner?(user)
    roles
  end

  def build_element_from_process(process)
    process_type = process.class.name
    audit_element = audit_elements.build(subject: process.title,
                                         process_id: process.id,
                                         process_type: process_type)

    if process.pilot.nil?
      # Le responsable de l'audit est auditeur par défaut.
      audit_element.audit_participants.build(participant: owner, auditor: true)
    elsif process.pilot == owner
      audit_element.audit_participants.build(
        participant: process.pilot, domain_responsible: true, auditor: true
      )
    else
      audit_element.audit_participants.build(
        participant: process.pilot, domain_responsible: true
      )
      audit_element.audit_participants.build(participant: owner, auditor: true)
    end

    audit_element
  end

  def build_element_from_title(title)
    audit_element = audit_elements.build(subject: title, process_type: nil)
    # Le responsable de l'audit est auditeur par défaut.
    audit_element.audit_participants.build(participant: owner, auditor: true)
    audit_element
  end

  def many_associations_to_track
    %w[theme_ids event_ids audit_element_ids audit_attachment_ids event_ids]
  end

  # TODO: Attributes that correspond to fields can be moved to
  # `fields_to_track` in the current `development` branch.
  def attributes_to_track
    %w[state owner_id real_started_at estimated_closed_at estimated_start_at
       object reference synthesis title]
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

  #
  # Marks the `audit_element_ids` for the current model as dirty, for use as an
  # association callback.
  #
  def mark_dirty_audit_element_ids(_record)
    mark_dirty_attribute :audit_element_ids
  end

  # Returns a hash of field names to track mapped to legacy timeline item key
  # names.
  #
  # FIXME: Although this definition does not belong in a method, I will create
  #   one here to keep all the definitions in one place.
  # TODO: Redesign methods *_to_track, when finished with double accounting.
  def fields_to_track
    {
      audit_attachments: "audit_attachment_ids",
      audit_scopes: "audit_theme_ids",
      audit_type: "audit_type_id",
      events: "event_ids"
    }
  end

  def reminder_category_for(attribute)
    "#{self.class.name.downcase}_#{attribute}"
  end

  def reminder_for(attribute, user)
    reminders.where("to_id = ? AND reminder_type = ? AND reminds_at > ?",
                    user.id,
                    reminder_category_for(attribute),
                    Date.today)
             .first_or_initialize(reminder_type: reminder_category_for(attribute))
  end

  def reminder_date_for(reminder_type)
    case reminder_type
    when "#{self.class.name.downcase}_estimated_start_at"
      estimated_start_at
    when "#{self.class.name.downcase}_estimated_closed_at"
      estimated_closed_at
    end
  end

  def reminder_schedulable_for?(type)
    case type
    when "#{self.class.name.downcase}_estimated_start_at"
      %w[planning planned].include?(state)
    when "#{self.class.name.downcase}_estimated_closed_at"
      %w[planning planned in_progress pending_approval].include?(state)
    else
      false
    end
  end

  def reminders_by_type(type)
    reminders.where("reminder_type = ? AND reminds_at > ?", type, Date.today)
  end

  def reminders_by_user(user_id)
    reminders.where("to_id = ? AND reminds_at > ?", user_id, Date.today)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity,Metrics/MethodLength, Metrics/PerceivedComplexity
  # TODO: Refactor `check_reminders` into 3 smaller methods
  def check_reminders
    # Changed needed for Rails 5.2 upgrade. attr_changed? will have opposite
    # behavior. Leaving code commented as this is not tested.
    #
    # if state_changed?
    if saved_change_to_state?
      if completed? || closed?
        destroy_scheduled_reminders
      elsif in_progress? || pending_approval?
        reminders_by_type("audit_estimated_start_at").each(&:destroy)
      end
    end

    # If remindable dates change
    %w[estimated_start_at estimated_closed_at].each do |attribute|
      # Changed needed for Rails 5.2 upgrade. changed? will have opposite
      # behavior. Leaving code commented as this is not tested.
      #
      # next unless changed.include?(attribute) && reminders_by_type(reminder_category_for(attribute)).any?
      next unless saved_changes.key?(attribute) &&
                  reminders_by_type(reminder_category_for(attribute)).any?

      reminders_by_type(reminder_category_for(attribute)).each do |current_reminder|
        current_reminder_hash = current_reminder.attributes.slice(
          %w[remindable_type remindable_id reminder_type from_id to_id]
        )
        new_reminder = reminders.new current_reminder_hash do |r|
          r.occurs_at = self[attribute]
          r.reminds_at = self[attribute] - current_reminder.duration_in_days.days
        end

        new_reminder.perform if current_reminder.destroy && new_reminder.save
      end
    end

    # If organizer or owner change
    %w[organizer_id owner_id].each do |attribute|
      # Changed needed for Rails 5.2 upgrade. changed? will have opposite
      # behavior. Leaving code commented as this is not tested.
      #
      # next unless changed.include?(attribute) && reminders_by_user(changes[attribute].first).any?
      next unless saved_changes.key?(attribute) &&
                  reminders_by_user(saved_changes[attribute].first).any?

      # saved_changes[attribute] returns the change to attribute, an array of
      # [before, after] values.
      previous_user = customer.users.find(saved_changes[attribute].first)
      # Let's destroy its reminders if he isn't currently in reminders_build_team.
      reminders_by_user(previous_user).each(&:destroy) unless previous_user.in_reminders_build_team_of?(self)
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity,Metrics/MethodLength, Metrics/PerceivedComplexity

  def destroy_scheduled_reminders
    # On détruit les objects et les jobs non échues
    reminders.where("reminds_at > ?", Date.today).each(&:destroy)
  end

  def participants
    res = [organizer, owner] + internal_auditors + internal_audited
    audit_elements.each do |audit_element|
      res << audit_element.domain_responsible unless audit_element.domain_responsible.nil?
    end
    res.uniq
  end

  def default_contributors
    User.where(id: [organizer, owner])
  end

  def contribution_editable?
    !completed? && !closed?
  end

  def late?
    if estimated_closed_at.nil?
      false
    else
      estimated_closed_at < Date.today && (planning? || planned? || in_progress? || pending_approval?)
    end
  end

  def late_by
    late? ? (Date.today - estimated_closed_at).to_i : 0
  end

  def task_date_for(category)
    created_at if CATEGORIES_FOR_AUDITS.include?(category.to_sym)
  end

  def includes_auditor?(user)
    audit_participants.any? do |audit_participant|
      audit_participant.auditor? && audit_participant.participant_id == user.id
    end
  end

  def includes_auditee?(user)
    audit_participants.any? do |audit_participant|
      audit_participant.audited? && audit_participant.participant_id == user.id
    end
  end

  def includes_domain_owner?(user)
    audit_participants.any? do |audit_participant|
      audit_participant.domain_responsible? && audit_participant.participant_id == user.id
    end
  end
end
