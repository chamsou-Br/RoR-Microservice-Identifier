# frozen_string_literal: true

# == Schema Information
#
# Table name: action_plans
#
#  id               :bigint(8)        not null, primary key
#  plan_frozen_date :datetime
#  plan_frozen      :boolean          default(FALSE), not null
#  plannable_type   :string(255)
#  plannable_id     :bigint(8)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_action_plans_on_plannable_type_and_plannable_id  (plannable_type,plannable_id)
#
class ActionPlan < ApplicationRecord
  validate :only_one_active, on: :create

  belongs_to :plannable, polymorphic: true
  has_and_belongs_to_many :acts, before_add: :check_if_frozen

  #
  # Create a new action plan based on another action plan
  #
  # @param [ActionPlan] other_plan
  # @return [ActionPlan]
  # @raise [ArgumentError] if `other_plan` is not an {ActionPlan}
  #
  def self.new_from(other_plan)
    unless other_plan.is_a?(self)
      raise ArgumentError,
            "Expected `other_plan` to be an #{name} but received " \
            "#{other_plan}"
    end

    # The new action plan should inherits all of the other plans actions.  Any
    # additional attributes it must inherit should be specified here.
    new(acts: other_plan.acts)
  end

  # Freezes the action plan by setting plan_frozen to true and setting the
  # date in plan_frozen_date.
  #
  # @return [Boolean] true when the update succeeds
  #
  def freeze_plan
    update(plan_frozen: true, plan_frozen_date: DateTime.now)
  end

  # Return true if action plan is frozen and false otherwise
  #
  # @return [Boolean]
  #
  def frozen_plan?
    plan_frozen? && plan_frozen_date.present?
  end

  private

  # This assumes that plannable has implemented active_action_plan
  def only_one_active
    return unless plannable&.active_action_plan

    errors.add(:base, message: "Only one active action plan is allowed")
  end

  def check_if_frozen(_act)
    return unless plan_frozen

    errors.add(:base, message: "Cannot add actions to a frozen plan")
    raise "Cannot add actions to a frozen plan"
  end
end
