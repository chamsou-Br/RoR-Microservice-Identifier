# frozen_string_literal: true

# == Schema Information
#
# Table name: assessment_scale_ratings
#
#  id                  :bigint(8)        not null, primary key
#  color               :string(255)      not null
#  value               :integer          not null
#  i18n_key            :string(255)
#  label               :string(255)
#  description         :text(65535)
#  assessment_scale_id :bigint(8)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#
# Indexes
#
#  index_assessment_scale_ratings_on_assessment_scale_id  (assessment_scale_id)
#
# Foreign Keys
#
#  fk_rails_...  (assessment_scale_id => assessment_scales.id)
#
class AssessmentScaleRating < ApplicationRecord
  belongs_to :assessment_scale

  # TODO: define what to do with class "RiskImpactDescription". Should it be
  # renamed to "ImpactDescription". Leaving as-is, will lead to confusion.
  #
  has_many :impact_descriptions,
           class_name: "RiskImpactDescription",
           foreign_key: :rating_id,
           dependent: :destroy

  validates :description, length: { maximum: 65_535 }

  def default_label
    i18n_key ? I18n.t(i18n_key, scope: "risk.scales.ratings") : nil
  end

  # This method returns true when one of `i18n_key` or `label` are present
  # and false if both are missing.
  #
  def valid_label?
    i18n_key.present? || label.present?
  end
end
