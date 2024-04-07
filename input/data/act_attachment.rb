# frozen_string_literal: true

# == Schema Information
#
# Table name: act_attachments
#
#  id         :integer          not null, primary key
#  act_id     :integer
#  title      :string(255)
#  file       :string(255)
#  author_id  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_act_attachments_on_act_id     (act_id)
#  index_act_attachments_on_author_id  (author_id)
#

class ActAttachment < ApplicationRecord
  include MediaFile
  include LinkableFieldable

  belongs_to :act, optional: true
  belongs_to :author,
             foreign_key: "author_id", class_name: "User", optional: true
end
