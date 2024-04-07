# frozen_string_literal: true

# == Schema Information
#
# Table name: mitigation_strategies
#
#  id         :integer          not null, primary key
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  risk_id    :integer
#
# Indexes
#
#  index_mitigation_strategies_on_risk_id  (risk_id)
#
# Foreign Keys
#
#  fk_rails_...  (risk_id => risks.id)
#

class MitigationStrategy < ApplicationRecord
  include FieldableEntity

  belongs_to :risk

  has_many :impactables_impacts, as: :impactable, dependent: :destroy
  has_many :linked_graphs, through: :impactables_impacts,
                           source: :impact,
                           source_type: "Graph"
  has_many :linked_documents, through: :impactables_impacts,
                              source: :impact,
                              source_type: "Document"

  delegate :customer, to: :risk
  delegate :customer_id, to: :risk
end
