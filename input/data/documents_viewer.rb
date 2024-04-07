# frozen_string_literal: true

# == Schema Information
#
# Table name: documents_viewers
#
#  id          :integer          not null, primary key
#  document_id :integer
#  viewer_id   :integer
#  viewer_type :string(255)
#
# Indexes
#
#  index_documents_viewers_on_document_id                (document_id)
#  index_documents_viewers_on_viewer_id_and_viewer_type  (viewer_id,viewer_type)
#

class DocumentsViewer < ApplicationRecord
  ### Elasticsearch
  include SearchableDocumentsViewer

  belongs_to :viewer, polymorphic: true
  belongs_to :document

  def self.duplicate_for(document_duplicated, document_template = nil)
    document_template = document_duplicated.parent if document_template.nil?
    document_template.documents_viewers.each do |document_viewer|
      document_viewer_duplicated = document_viewer.dup
      document_viewer_duplicated.document = document_duplicated
      document_viewer_duplicated.save
    end
  end
end
