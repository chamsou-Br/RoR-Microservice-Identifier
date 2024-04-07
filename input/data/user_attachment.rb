# frozen_string_literal: true

# == Schema Information
#
# Table name: user_attachments
#
#  id         :integer          not null, primary key
#  user_id    :integer
#  title      :string(255)
#  file       :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class UserAttachment < ApplicationRecord
  include MediaFile

  belongs_to :user, optional: true

  validate :cannot_exceed_attachment_limit

  def cannot_exceed_attachment_limit
    return unless user.attachments.count >= User::ATTACHMENTS_LIMIT

    errors.add :base, I18n.t("attachments.errors.base.limit_upload_reached")
  end
end
