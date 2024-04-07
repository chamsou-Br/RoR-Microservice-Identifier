# frozen_string_literal: true

# == Schema Information
#
# Table name: evaluations
#
#  id                   :integer          not null, primary key
#  risk_id              :integer
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  submitted_at         :datetime
#  evaluation_system_id :integer
#
# Indexes
#
#  index_evaluations_on_evaluation_system_id  (evaluation_system_id)
#  index_evaluations_on_risk_id               (risk_id)
#
# Foreign Keys
#
#  fk_rails_...  (evaluation_system_id => evaluation_systems.id)
#  fk_rails_...  (risk_id => risks.id)
#

class Evaluation < ApplicationRecord
  belongs_to :risk, inverse_of: :evaluations
  belongs_to :evaluation_system
  validate :applicable_eval_system, on: :create

  include FieldableEntity

  # Track changes to rails attributes and field values
  has_paper_trail meta: {
    fields: lambda do |evaluation|
      FieldValueCodec.encode_values(evaluation.fieldable_values)
    end
  }

  delegate :customer, to: :risk
  delegate :customer_id, to: :risk

  #
  # Submits the evaluation.  If the evaluation has already been submitted, this
  # does nothing.
  #
  # @return [Evaluation]
  #
  def submit
    self.submitted_at ||= Time.now
    self
  end

  #
  # Has the evaluation been submitted?
  #
  # @return [Boolean]
  def submitted?
    !!(submitted_at&.<= Time.now)
  end

  # Used in graphql typing
  alias submitted submitted?

  # If the evaluation system is not applicable, the evaluation is not created.
  #
  def applicable_eval_system
    return if evaluation_system&.applicable?

    errors.add(:evaluation_system_id, "is not applicable")
  end
end
