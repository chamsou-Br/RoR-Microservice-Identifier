# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_like_events
#
#  id              :integer          not null, primary key
#  event_id        :integer
#  audit_like_id   :integer
#  audit_like_type :string(255)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  audit_event_link                                              (event_id,audit_like_id,audit_like_type) UNIQUE
#  index_audit_like_events_on_audit_like_id_and_audit_like_type  (audit_like_id,audit_like_type)
#  index_audit_like_events_on_event_id                           (event_id)
#

class AuditLikeEvent < ApplicationRecord
  belongs_to :audit_like, polymorphic: true
  belongs_to :event

  validates :event_id, uniqueness: { scope: %i[audit_like_id audit_like_type] }
end
