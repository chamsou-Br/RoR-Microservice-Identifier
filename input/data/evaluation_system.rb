# frozen_string_literal: true

# == Schema Information
#
# Table name: evaluation_systems
#
#  id          :integer          not null, primary key
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  customer_id :integer
#  title       :string(765)
#  state       :integer
#
# Indexes
#
#  fk_rails_1054c3e588  (customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#

class EvaluationSystem < ApplicationRecord
  include EvalSystemStateMachine

  belongs_to :customer, inverse_of: :evaluation_systems

  has_many :evaluations
  has_many :form_fields, dependent: :destroy
  has_many :impacts,
           class_name: "RiskImpact",
           inverse_of: :evaluation_system,
           dependent: :destroy
  has_many :scales, class_name: "AssessmentScale", dependent: :destroy

  scope :newest, -> { order(created_at: :desc) }

  enum state: { draft: 0,
                applicable: 1,
                archived: 2 }

  validates :state, inclusion: { in: EvaluationSystem.states.keys }
  validates :title, presence: true, length: { maximum: 765 }
  validate :only_one_applicable, :only_one_draft

  def impact_scale
    scales.find_by(scale_type: :impact)
  end

  def likelihood_scale
    scales.find_by(scale_type: :likelihood)
  end

  def threat_level_scale
    scales.find_by(scale_type: :threat_level)
  end

  #
  # An evaluation system cannot be edited if it is applicable or archived.
  # IOW, an evaluation system is only editable when it is in `:draft`.
  #
  # @return `true` if this evaluation system cannot be edited
  #
  def immutable?
    !mutable?
  end

  #
  # @return `true` if this evaluation system can be edited
  #
  def mutable?
    draft?
  end

  #
  # @return `false` if there is only one evaluation system in the DB for
  #   the customer of this evaluation system. The last evaluation system of a
  #   customer cannot be deleted.
  # @return `false` if this evaluation system has eny evaluations.
  # @return `true` if this evaluation system is in `:draft` or
  #   `:archived` without evaluations.
  #
  def deleteable?
    return false if EvaluationSystem.where(customer: customer).count == 1
    return false if evaluations.any?

    draft? || archived?
  end

  alias applicable applicable?
  alias deleteable deleteable?
  alias mutable mutable?

  private

  def only_one_applicable
    return unless applicable?

    applicables = customer.evaluation_systems.where(state: "applicable")
    return if applicables.empty? || (applicables.uniq == [self])

    errors.add(:base, "Customer already has an applicable evaluation system")
  end

  def only_one_draft
    return unless draft?

    drafts = customer.evaluation_systems.where(state: "draft")
    return if drafts.empty? || (drafts.uniq == [self])

    errors.add(:base, "Customer already has a draft evaluation system")
  end
end
