# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_attachments
#
#  id         :integer          not null, primary key
#  audit_id   :integer
#  title      :string(255)
#  file       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  author_id  :integer
#
# Indexes
#
#  index_audit_attachments_on_audit_id   (audit_id)
#  index_audit_attachments_on_author_id  (author_id)
#

class AuditAttachment < ApplicationRecord
  include MediaFile
  include LinkableFieldable

  belongs_to :audit, optional: true
  belongs_to :author,
             foreign_key: "author_id", class_name: "User", optional: true
end
