# frozen_string_literal: true

# == Schema Information
#
# Table name: risk_impacts
#
#  id                   :bigint(8)        not null, primary key
#  evaluation_system_id :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  form_field_id        :integer
#
# Indexes
#
#  index_risk_impacts_on_evaluation_system_id  (evaluation_system_id)
#  index_risk_impacts_on_form_field_id         (form_field_id)
#
# Foreign Keys
#
#  fk_rails_...  (evaluation_system_id => evaluation_systems.id)
#  fk_rails_...  (form_field_id => form_fields.id)
#
class RiskImpact < ApplicationRecord
  belongs_to :evaluation_system
  belongs_to :form_field, validate: true

  has_many :descriptions,
           class_name: "RiskImpactDescription",
           foreign_key: :impact_id,
           dependent: :destroy

  delegate :default_label, :label, :custom?, :visible?, to: :form_field

  def title
    label || default_label
  end

  def required?
    form_field.not_optional?
  end
end
