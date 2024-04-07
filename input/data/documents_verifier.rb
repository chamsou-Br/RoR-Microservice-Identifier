# frozen_string_literal: true

# == Schema Information
#
# Table name: documents_verifiers
#
#  id          :integer          not null, primary key
#  document_id :integer
#  verifier_id :integer
#  verified    :boolean          default(FALSE), not null
#  comment     :string(765)
#  historized  :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_documents_verifiers_on_document_id                  (document_id)
#  index_documents_verifiers_on_document_id_and_verifier_id  (document_id,verifier_id)
#  index_documents_verifiers_on_verifier_id                  (verifier_id)
#

class DocumentsVerifier < ApplicationRecord
  ## Elasticsearch
  include SearchableDocumentsVerifier

  # @!attribute [rw] verifier
  #   @return [User]
  belongs_to :verifier, class_name: "User"

  # @!attribute [rw] document
  #   @return [Document]
  belongs_to :document

  scope :current, -> { where(historized: false) }
  scope :pending, -> { where(historized: false, verified: false) }

  before_save :check_comment

  def self.duplicate_for(document_duplicated, document_template = nil)
    document_template = document_duplicated.parent if document_template.nil?
    document_template.documents_verifiers.current.each do |document_verifier|
      document_verifier_duplicated = document_verifier.dup
      document_verifier_duplicated.document = document_duplicated
      document_verifier_duplicated.verified = false
      document_verifier_duplicated.comment = nil
      document_verifier_duplicated.save
    end
  end

  #
  # The full name of the verifier
  #
  # @return [String]
  # @deprecated Use the `#verifier` directly to get the {User} and get its full
  #   name with {User#name} and {User::Name#full}.
  #
  def display_verifier_username
    verifier.name.full
  end

  def check_comment
    return unless !comment.nil? && comment.length > document.comment_wf_max_length

    self.comment = comment[0..(document.comment_wf_max_length - 1)]
  end
end
