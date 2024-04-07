# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_element_subjects
#
#  id         :integer          not null, primary key
#  subject    :string(255)
#  audit_id   :integer          not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class AuditElementSubject < ApplicationRecord
  belongs_to :audit
  has_many :audit_elements

  has_many :audit_element_subject_audit_events, dependent: :destroy
  has_many :audit_events, through: :audit_element_subject_audit_events

  validates :subject, presence: true
  validates :audit, presence: true
end
