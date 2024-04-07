# frozen_string_literal: true

# == Schema Information
#
# Table name: contributables_contributors
#
#  id                 :integer          not null, primary key
#  contributor_id     :integer
#  contributable_id   :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  contributable_type :string(255)
#
# Indexes
#
#  index_cc_cid_ctype                                   (contributable_id,contributable_type)
#  index_contributables_contributors_on_contributor_id  (contributor_id)
#

class ContributablesContributor < ApplicationRecord
  ## Elasticsearch
  include SearchableGraphsContributor

  # attr_accessible :contributor_id, :graph_id

  belongs_to :contributor, class_name: "User", required: false
  belongs_to :orig_contributor,
             class_name: "User", foreign_key: "contributor_id"

  belongs_to :contributable, polymorphic: true

  validates :contributor_id, uniqueness: {
    is: true,
    scope: %i[contributable_id contributable_type],
    message: I18n.t("activerecord.models.contributables_contributor.unique")
  }

  def self.import_to_es
    # rubocop:disable Style/RescueModifier
    Graph.__elasticsearch__.client.indices.delete index: Graph.index_name rescue nil
    # rubocop:enable Style/RescueModifier
    Graph.__elasticsearch__.client.indices.create \
      index: Graph.index_name,
      body: {
        settings: Graph.settings.to_hash,
        mappings: Graph.mapping
      }

    ContributablesContributor.import transform: lambda { |object|
      {
        index: {
          _id: object.id,
          _parent: object.contributable_id,
          data: object.__elasticsearch__.as_indexed_json
        }
      }
    }
  end
end
