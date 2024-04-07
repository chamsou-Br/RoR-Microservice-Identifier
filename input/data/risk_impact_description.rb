# frozen_string_literal: true

# == Schema Information
#
# Table name: risk_impact_descriptions
#
#  id         :bigint(8)        not null, primary key
#  text       :text(65535)
#  impact_id  :bigint(8)
#  rating_id  :bigint(8)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_risk_impact_descriptions_on_impact_id  (impact_id)
#  index_risk_impact_descriptions_on_rating_id  (rating_id)
#
# Foreign Keys
#
#  fk_rails_...  (impact_id => risk_impacts.id)
#  fk_rails_...  (rating_id => assessment_scale_ratings.id)
#
class RiskImpactDescription < ApplicationRecord
  belongs_to :impact, class_name: "RiskImpact"
  belongs_to :rating, class_name: "AssessmentScaleRating"

  validates :text, length: { maximum: 65_535 }
end
