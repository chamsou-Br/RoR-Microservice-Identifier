# frozen_string_literal: true

# == Schema Information
#
# Table name: impactables_impacts
#
#  id              :integer          not null, primary key
#  impactable_id   :integer
#  impact_id       :integer
#  impact_type     :string(255)
#  impactable_type :string(255)
#  title           :string(255)
#
# Indexes
#
#  index_impactables_impacts_on_impact_id_and_impact_type          (impact_id,impact_type)
#  index_impactables_impacts_on_impactable_id_and_impactable_type  (impactable_id,impactable_type)
#

class ImpactablesImpact < ApplicationRecord
  belongs_to :impactable, polymorphic: true
  belongs_to :impact, polymorphic: true

  validates :impact_type, presence: true, inclusion: { in: %w[Graph Document] },
                          allow_nil: true
  validates :impactable_type,
            presence: true,
            inclusion: { in: %w[Event Act Risk MitigationStrategy] }

  validates :title, presence: true, if: proc { |impact| impact.impact_type.blank? }

  before_save :check_title

  # TODO: Rename `is_custom?` to `custom?`
  # rubocop:disable Naming/PredicateName
  def is_custom?
    !title.nil? && impact_type.nil?
  end
  # rubocop:enable Naming/PredicateName

  def check_title
    self.title = nil if impact_type.present?
  end
end
