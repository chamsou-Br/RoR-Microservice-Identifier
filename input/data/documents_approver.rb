# frozen_string_literal: true

# == Schema Information
#
# Table name: documents_approvers
#
#  id          :integer          not null, primary key
#  document_id :integer
#  approver_id :integer
#  approved    :boolean          default(FALSE), not null
#  comment     :string(765)
#  historized  :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_documents_approvers_on_approver_id                  (approver_id)
#  index_documents_approvers_on_approver_id_and_document_id  (approver_id,document_id)
#  index_documents_approvers_on_document_id                  (document_id)
#

class DocumentsApprover < ApplicationRecord
  ### Elasticsearch
  include SearchableDocumentsApprover

  belongs_to :approver, class_name: "User"
  belongs_to :document

  scope :current, -> { where(historized: false) }
  scope :pending, -> { where(historized: false, approved: false) }

  before_save :check_comment

  def self.duplicate_for(document_duplicated, document_template = nil)
    document_template = document_duplicated.parent if document_template.nil?
    document_template.documents_approvers.current.each do |document_approver|
      document_approver_duplicated = document_approver.dup
      document_approver_duplicated.document = document_duplicated
      document_approver_duplicated.approved = false
      document_approver_duplicated.comment = nil
      document_approver_duplicated.save
    end
  end

  def check_comment
    return unless !comment.nil? && comment.length > document.comment_wf_max_length

    self.comment = comment[0..(document.comment_wf_max_length - 1)]
  end
end
