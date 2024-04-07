# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_elements
#
#  id                       :integer          not null, primary key
#  audit_id                 :integer
#  start_date               :datetime
#  end_date                 :datetime
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#  process_id               :integer
#  process_type             :string(255)
#  audit_element_subject_id :integer
#  subject                  :string(255)
#
# Indexes
#
#  index_audit_elements_on_audit_id                     (audit_id)
#  index_audit_elements_on_process_id_and_process_type  (process_id,process_type)
#

# TODO: Shrink `AuditElement` into smaller class perhaps using modules
class AuditElement < ApplicationRecord
  include LinkableFieldable

  belongs_to :audit, inverse_of: :audit_elements

  has_many :audit_like_events, as: :audit_like
  has_many :events, through: :audit_like_events

  # The two processes are: Graph and Document.
  belongs_to :process, polymorphic: true, optional: true

  # This association is needed for the migration of subject to the audit_element
  belongs_to :audit_element_subject, optional: true

  # Responsibilities
  has_many :audit_participants, dependent: :destroy, autosave: true
  accepts_nested_attributes_for :audit_participants, allow_destroy: true

  # TODO: has_one here is used to enforce the unique existence of a domain owner.
  # It is not an ActiveRecord association. It looks and feels wrong.
  # Better would be to reinforce uniqueness on:
  # audit_participant_id, audit_element_id when { domain_responsible: true }
  has_one :element_domain_responsible, -> { where(audit_participants: { domain_responsible: true }) },
          class_name: "AuditParticipant", dependent: :destroy
  has_one :domain_responsible, through: :element_domain_responsible,
                               source: :participant, source_type: "User",
                               foreign_key: "participant_id"
  accepts_nested_attributes_for :element_domain_responsible, allow_destroy: true

  has_many :internal_auditors, -> { where(audit_participants: { auditor: true }) },
           through: :audit_participants, source: :participant,
           source_type: "User"
  has_many :external_auditors, -> { where(audit_participants: { auditor: true }) },
           through: :audit_participants, source: :participant,
           source_type: "ExternalUser"
  has_one :domain_owner, -> { where(audit_participants: { domain_responsible: true }) },
          through: :audit_participants, source: :participant,
          source_type: "User"

  has_many :internal_audited, -> { where(audit_participants: { audited: true }) },
           through: :audit_participants, source: :participant, source_type: "User"
  has_many :external_audited, -> { where(audit_participants: { audited: true }) },
           through: :audit_participants, source: :participant, source_type: "ExternalUser"

  validates :start_date, presence: true
  validates :end_date, presence: true
  validates :process_type, inclusion: { in: %w[Graph Document] },
                           allow_nil: true

  validate :check_responsibilities

  # Validatios to check.
  validate :check_participant_privilege, on: :update
  validate :check_audit_participants_audition, on: :update

  def involved_responsibilities
    [
      { responsibility: "auditor", users: auditors_serialized },
      { responsibility: "auditee", users: auditees_serialized },
      { responsibility: "domain_owner",
        users: [domain_responsible&.serialize_this&.deep_symbolize_keys] }
    ].select { |r| r[:users].any? }
  end

  def check_audit_participants_audition
    audit_participants.each do |participant|
      next unless participant.auditor? && participant.audited?

      errors.add(:base, :audition_inconsistency,
                 name: if participant.participant.is_a?(User)
                         participant.participant.name.full
                       else
                         # participant is an {ExternalUser}
                         participant.participant.name
                       end)
    end
  end

  # rubocop:disable Metrics/CyclomaticComplexity
  def check_responsibilities
    audit_participants.map(&:validate)
    partial_participants = audit_participants.select do |participant|
      participant.marked_for_destruction? &&
        !(participant.audited? ||
          participant.auditor? ||
          participant.domain_responsible?)
    end
    return if partial_participants.empty?

    partial_participants.each do |participant|
      errors.add(
        :base, :participant_without_role,
        # TODO: Should fail if the `participant` is an {ExternalUser}
        name: participant.participant.name.full
      )
      errors.add(
        :base, particiapant, errors
      )
    end
  end

  # TODO: DEPRECATED
  # TODO: Refactor `check_role_assignment` into smaller private methods
  # FIXME: my searches do not find a use of this method.
  # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
  def check_role_assignation
    participants = audit_participants.select do |participant|
      !participant.marked_for_destruction? &&
        (participant.audited == false || participant.audited.blank?) &&
        (participant.auditor == false || participant.auditor.blank?) &&
        (participant.domain_responsible == false || participant.domain_responsible.blank?)
    end

    return true if participants.blank?

    participants.each do |participant|
      errors.add(:base, :participant_without_role,
                 name: if participant.participant.is_a?(User)
                         participant.participant.name.full
                       else
                         participant.participant.name
                       end)
    end

    false
  end

  # TODO: Refactor `check_participant_privilege` to use customer scopes
  def check_participant_privilege
    participants_to_check = audit_participants.select { |p| !p.marked_for_destruction? && p.participant.is_a?(User) }

    # @type [Array<User>]
    obsolete_auditors = audit.customer.users.where(
      id: participants_to_check.select { |p| p.auditor == true }.map { |p| p[:participant_id] },
      improver_profile_type: :user
    )

    # @type [Array<User>]
    deactivated_participants = audit.customer.users.where(
      id: participants_to_check.map { |p| p[:participant_id] }, deactivated: true
    )

    return true if deactivated_participants.blank? && obsolete_auditors.blank?

    deactivated_participants.each do |participant|
      errors.add(:base, :deactivated_participant, name: participant.name.full)
    end

    obsolete_auditors.each do |participant|
      errors.add(:base, :participant_cannot_be_auditor, name: participant.name.full)
    end

    false
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # TODO: Rename `is_process?` to `process?`
  # rubocop:disable Naming/PredicateName
  def is_process?
    !process_id.nil?
  end
  # rubocop:enable Naming/PredicateName

  def auditors
    audit_participants.where(auditor: true)
  end

  def auditees
    audit_participants.where(audited: true)
  end

  def auditors_serialized
    auditors.map do |auditor|
      auditor.participant.serialize_this.deep_symbolize_keys
    end
  end

  def auditees_serialized
    auditees.map do |auditee|
      auditee.participant.serialize_this.deep_symbolize_keys
    end
  end

  def check_dates
    errors.add(:start_date, :earlier_than_start) if !start_date.blank? && !end_date.blank? && start_date > end_date
  end

  def build_participant_with_custom_user(attributes)
    custom_user = attributes[:type].constantize.new
    custom_user.attributes = { name: attributes[:name], customer_id: attributes[:customer_id] }
    participant = audit_participants.build
    participant.participant = custom_user
    participant
  end
end
