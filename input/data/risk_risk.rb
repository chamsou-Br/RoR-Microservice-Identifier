# frozen_string_literal: true

# == Schema Information
#
# Table name: risk_risks
#
#  id             :bigint(8)        not null, primary key
#  risk_id        :integer
#  linked_risk_id :integer
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#
# Indexes
#
#  index_risk_risks_on_linked_risk_id              (linked_risk_id)
#  index_risk_risks_on_risk_id                     (risk_id)
#  index_risk_risks_on_risk_id_and_linked_risk_id  (risk_id,linked_risk_id) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (linked_risk_id => risks.id)
#  fk_rails_...  (risk_id => risks.id)
#
class RiskRisk < ApplicationRecord
  belongs_to :risk
  belongs_to :linked_risk, class_name: "Risk"

  after_create :create_reciprocal, unless: :reciprocal?
  after_destroy :destroy_reciprocal, if: :reciprocal?

  validate :different_risk?

  def create_reciprocal
    self.class.create(reciprocal_options)
  end

  def destroy_reciprocal
    reciprocal.destroy_all
  end

  def reciprocal?
    self.class.exists?(reciprocal_options)
  end

  def reciprocal
    self.class.where(reciprocal_options)
  end

  def reciprocal_options
    { linked_risk_id: risk_id, risk_id: linked_risk_id }
  end

  def different_risk?
    errors.add(:base, "Cannot link to self") if risk == linked_risk
  end
end
