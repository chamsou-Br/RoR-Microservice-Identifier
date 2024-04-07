# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_participants
#
#  id                 :integer          not null, primary key
#  audit_element_id   :integer
#  auditor            :boolean          default(FALSE)
#  audited            :boolean          default(FALSE)
#  participant_id     :integer
#  participant_type   :string(255)
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  domain_responsible :boolean          default(FALSE)
#
# Indexes
#
#  index_audit_participants_on_audit_element_id  (audit_element_id)
#  index_audit_participants_on_participant       (participant_id,participant_type)
#

class AuditParticipant < ApplicationRecord
  # @!attribute [rw] participant
  #   @return [ExternalUser, User]
  # NOTE: the polymorphic relation is not used correctly. The two particiapnt
  # types are: User and ExternalUser
  belongs_to :participant, polymorphic: true, autosave: true
  belongs_to :audit_element, optional: true

  has_one :audit, through: :audit_element

  validates :participant_id, uniqueness: { scope: %i[audit_element_id
                                                     participant_type] }
  accepts_nested_attributes_for :participant, allow_destroy: true

  after_destroy :destroy_reminders, if: :internal_user_with_reminders?
  after_update :destroy_reminders, if: :was_internal_auditor_with_reminders?

  validate :check_auditor

  def was_internal_auditor_with_reminders?
    internal_user_with_reminders? && auditor_before_last_save
  end

  def participant_attributes=(attributes)
    user = participant_type.constantize.new
    user.attributes = attributes
    self.participant = user
  end

  def destroy_external_users
    participant.destroy unless participant.is_a?(User)
  end

  def internal_user_with_reminders?
    participant.is_a?(User) && audit.reminders_by_user(participant_id).any?
  end

  def destroy_reminders
    return if participant.in_reminders_build_team_of?(audit)

    audit.reminders_by_user(participant_id).each(&:destroy)
  end

  # TODO: checking this here is terrible. According to this an auditor can
  # not be simple user. So instead of logging the error it simply sets the
  # flag here to false :horror:
  # For now, setting auditor to false so the validation in audit_elelment
  # fails, and the record is not saved.
  def check_auditor
    return unless participant.is_a?(User) && auditor == true
    # TODO: this will fail if participant is ExternalUser.
    return unless participant.improver_user?

    self.auditor = false
    errors.add(
      :auditor, "cannot be a simple user.",
      name: participant.name.full
    )
  end
end
