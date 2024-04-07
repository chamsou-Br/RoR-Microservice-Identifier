# frozen_string_literal: true

# == Schema Information
#
# Table name: role_attachments
#
#  id         :integer          not null, primary key
#  role_id    :integer
#  author_id  :integer
#  title      :string(255)
#  file       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_role_attachments_on_author_id  (author_id)
#  index_role_attachments_on_role_id    (role_id)
#
# Foreign Keys
#
#  fk_rails_...  (author_id => users.id)
#  fk_rails_...  (role_id => roles.id)
#

class RoleAttachment < ApplicationRecord
  include MediaFile

  belongs_to :role, optional: true
  belongs_to :author,
             foreign_key: "author_id", class_name: "User", optional: true

  validate :cannot_exceed_attachment_limit

  def cannot_exceed_attachment_limit
    return unless role.attachments.count >= Role::ATTACHMENTS_LIMIT

    errors.add :base, I18n.t("attachments.errors.base.limit_upload_reached")
  end
end
