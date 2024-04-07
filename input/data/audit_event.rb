# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_events
#
#  id         :integer          not null, primary key
#  audit_id   :integer
#  event_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_audit_events_on_audit_id  (audit_id)
#  index_audit_events_on_event_id  (event_id)
#

class AuditEvent < ApplicationRecord
  belongs_to :audit
  belongs_to :event

  has_many :audit_element_subject_audit_events, dependent: :destroy
  has_many :audit_element_subjects, through: :audit_element_subject_audit_events

  after_commit on: %i[create destroy] do |audit_event|
    audit_event.event.__elasticsearch__.update_document
  end
end
