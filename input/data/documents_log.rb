# frozen_string_literal: true

# == Schema Information
#
# Table name: documents_logs
#
#  id          :integer          not null, primary key
#  document_id :integer
#  action      :string(255)
#  comment     :string(765)
#  user_id     :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_documents_logs_on_document_id  (document_id)
#  index_documents_logs_on_user_id      (user_id)
#

class DocumentsLog < ApplicationRecord
  belongs_to :document
  belongs_to :user

  validates :document, presence: true
  validates :action, presence: true

  before_save :check_comment

  def check_comment
    return unless !comment.nil? && comment.length > document.comment_wf_max_length

    self.comment = comment[0..(document.comment_wf_max_length - 1)]
  end
end
