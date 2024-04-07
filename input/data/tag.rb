# frozen_string_literal: true

# == Schema Information
#
# Table name: tags
#
#  id          :integer          not null, primary key
#  label       :string(255)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  customer_id :integer
#
# Indexes
#
#  index_tags_on_customer_id  (customer_id)
#  index_tags_on_label        (label)
#

class Tag < ApplicationRecord
  include Sanitizable
  ### Elasticsearch
  include SearchableTag

  sanitize_fields :label

  scope :autocompleter, ->(query) { where("label like :q", q: "%#{query}%").order("label ASC") }

  belongs_to :customer

  has_many :taggings, dependent: :destroy
  has_many :roles, through: :taggings, source: :taggable, source_type: "Role"
  has_many :graphs, through: :taggings, source: :taggable, source_type: "Graph"
  has_many :documents, through: :taggings, source: :taggable, source_type: "Document"
  has_many :resources, through: :taggings, source: :taggable, source_type: "Resource"
  has_many :packages, through: :taggings, source: :taggable, source_type: "Package"

  validates :label, presence: true,
                    uniqueness: { scope: [:customer_id] }

  # TODO: Use double splat to accept generic options arguments
  def as_json(_options)
    { id: id, text: label }
  end

  def linked_elements_counter(user)
    # rubocop:disable Performance/Count
    # TODO: Use scopes and `count` instead of select
    roles.count +
      graphs.select { |g| GraphPolicy.viewable?(user, g) && !g.in_archives? }.count +
      documents.select { |d| DocumentPolicy.viewable?(user, d) && !d.in_archives? }.count +
      resources.count
    # rubocop:enable Performance/Count
  end
end
