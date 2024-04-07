# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_element_subject_audit_events
#
#  id                       :integer          not null, primary key
#  audit_element_subject_id :integer
#  audit_event_id           :integer
#  created_at               :datetime         not null
#  updated_at               :datetime         not null
#

# This model is a link between audit_events and audit_element_subjects.
# So an event is linked to an audit only once, even if it use multiple subjects
# of the same audit.
class AuditElementSubjectAuditEvent < ApplicationRecord
  belongs_to :audit_event
  belongs_to :audit_element_subject
end
