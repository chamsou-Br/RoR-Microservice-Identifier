# frozen_string_literal: true

# == Schema Information
#
# Table name: document_publishers
#
#  id           :integer          not null, primary key
#  document_id  :integer
#  publisher_id :integer
#  published    :boolean
#  publish_date :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_document_publishers_on_document_id   (document_id)
#  index_document_publishers_on_publisher_id  (publisher_id)
#

class DocumentPublisher < ApplicationRecord
  ## Elasticsearch
  include SearchableDocumentsPublisher

  validates :document_id, uniqueness: true

  belongs_to :publisher, class_name: "User"
  belongs_to :document

  def self.duplicate_for(document_duplicated, document_template = nil)
    document_template = document_duplicated.parent if document_template.nil?
    document_publisher = document_template.document_publisher
    return if document_publisher.nil?

    document_publisher_duplicated = document_publisher.dup
    document_publisher_duplicated.document = document_duplicated
    document_publisher_duplicated.published = nil
    document_publisher_duplicated.publish_date = nil
    document_publisher_duplicated.save
  end
end
