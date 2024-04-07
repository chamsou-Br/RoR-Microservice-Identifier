# frozen_string_literal: true

# == Schema Information
#
# Table name: assessment_scales
#
#  id                     :bigint(8)        not null, primary key
#  impact_system_id       :integer
#  likelihood_system_id   :integer
#  threat_level_system_id :integer
#  scale_type             :integer
#  evaluation_system_id   :integer
#
# Indexes
#
#  index_assessment_scales_on_evaluation_system_id    (evaluation_system_id)
#  index_assessment_scales_on_impact_system_id        (impact_system_id)
#  index_assessment_scales_on_likelihood_system_id    (likelihood_system_id)
#  index_assessment_scales_on_threat_level_system_id  (threat_level_system_id)
#
# Foreign Keys
#
#  fk_rails_...  (evaluation_system_id => evaluation_systems.id)
#  fk_rails_...  (impact_system_id => evaluation_systems.id)
#  fk_rails_...  (likelihood_system_id => evaluation_systems.id)
#  fk_rails_...  (threat_level_system_id => evaluation_systems.id)
#
class AssessmentScale < ApplicationRecord
  belongs_to :evaluation_system

  has_many :ratings, class_name: "AssessmentScaleRating", dependent: :destroy

  enum scale_type: {
    impact: 10,
    likelihood: 20,
    threat_level: 30
  }

  # This method returns true when all the values of the set of scales is
  # unique, false when at least one is repeated.
  # TODO: Find a more efficient and elegant method. It is not straight forward.
  #
  def unique_value_per_scale?
    values = ratings.map(&:value)
    !values.detect { |e| values.count(e) > 1 }
  end
end
