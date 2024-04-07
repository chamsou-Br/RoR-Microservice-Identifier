# frozen_string_literal: true

# == Schema Information
#
# Table name: risks
#
#  id                 :integer          not null, primary key
#  customer_id        :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#  state              :integer
#  internal_reference :string(255)
#
# Indexes
#
#  index_risks_on_customer_id  (customer_id)
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#

# The class is responsible for managing risk records per customer
class Risk < ApplicationRecord
  include RiskStateMachine
  include Discussion::Discussable
  include IamEntitySetup
  include IamApiMethods
  include InternalReference
  include SearchableRisk

  # Include relations and behaviors Risk needs from form fields, field items
  # and field values
  include FieldableEntity

  include Notice::RiskNotification
  # notification-handler of notifications-rails
  notification_object

  # Since Risk uses a simpler actor relation, this is retrieved this way.
  # TODO: Allow `discussable_by` to function this way be default to simplify
  #   usage when action, audits, events and graphs use this type of actor
  #   relation
  #
  discussable_by do
    actors
      .select { |actor| %w[contributor owner].include?(actor.responsibility) }
      .map(&:responsible)
  end

  # associations
  belongs_to :customer, inverse_of: :risks

  # Tracks historical changes in state with messages
  has_many :state_changes, as: :entity,
                           class_name: "StateMachines::StateChange",
                           dependent: :destroy,
                           inverse_of: :entity

  has_many :evaluations, dependent: :destroy
  has_many :mitigation_strategies, dependent: :destroy

  has_many :impactables_impacts, as: :impactable, dependent: :destroy
  has_many :affected_graphs, through: :impactables_impacts,
                             source: :impact,
                             source_type: "Graph"
  has_many :affected_documents, through: :impactables_impacts,
                                source: :impact,
                                source_type: "Document"

  has_and_belongs_to_many :events
  has_and_belongs_to_many :affected_process_roles, class_name: "Role"

  has_many :risk_risks
  has_many :linked_risks, through: :risk_risks, dependent: :destroy

  has_many :entity_reviews,
           as: :entity,
           inverse_of: :entity,
           dependent: :destroy

  has_many :action_plans,
           as: :plannable,
           source_type: "Risk",
           dependent: :destroy
  has_many :acts, through: :action_plans

  # Track changes to rails attributes and field values
  # TODO: Track changes to associated records
  #
  # `reload` forces the encoding on the values on DB and not in memory.
  #
  has_paper_trail meta: {
    fields: lambda do |risk|
      FieldValueCodec.encode_values(risk.reload.fieldable_values)
    end
  }

  # validations
  validates :state, :customer, :internal_reference, presence: true
  validates :internal_reference, uniqueness: { scope: [:customer_id] }

  enum state: { under_analysis: 0,
                pending_approval: 1,
                completed: 2,
                closed: 3,
                pending_closure: 4 }

  scope :with_involved_user, lambda { |user|
    risks = left_outer_joins(:actors).distinct
    risks.where(actors: { responsible: user })
  }

  # Prefetch actors involved in this risk
  scope :with_preloaded_actors, -> { preload(actors: :responsible) }

  # Returns the action plan that is not frozen. There should be only one.
  #
  # @return [ActionPlan]
  #
  def active_action_plan
    action_plans.find_by(plan_frozen: false, plan_frozen_date: nil)
  end

  # Returns the action plan which was last frozen.
  #
  # @return [ActionPlan]
  #
  def latest_frozen_plan
    action_plans.where(plan_frozen: true).order(plan_frozen_date: :desc).first
  end

  # Returns the default action plan to display depending on the state. When
  # the risk is `:under_analysis`, `:pending_approval` or `:pending_closure`,
  # the active action plan applies. If the risk is `:completed` or `:closed`,
  # the latest frozen action plan applies.
  #
  # @return [ActionPlan]
  #
  def current_action_plan
    case state
    when "under_analysis", "pending_approval", "pending_closure"
      active_action_plan
    else
      latest_frozen_plan
    end
  end

  # For the risk export we want to be able to export the reference if it exist
  # and nothing if not, since internal_reference is another column
  def current_reference
    reference = field_value_value("reference")
    reference.present? ? reference : ""
  end

  # Returns the last evaluation according to the `created_at` time. Evaluations
  # should only get created in chronological order when using strictly the UI.
  # TODO: We seem to be missing #active_evaluation...
  def last_evaluation
    evaluations.order(created_at: :desc).first
  end

  # Returns the response strategy of the last evaluation according the
  # `created_at` time. The response strategy is the `i18n_key` of the
  # `field_item` linked to the `field_value` of the `response_strategy`
  # `form_field`.
  #
  def response_strategy
    last_evaluation&.field_value_evaluation(
      "response_strategy", last_evaluation.evaluation_system
    )&.i18n_key
  end

  # Does this user have any role on the risk?
  # TODO: This method is the responsibility of the IAM service. It should be
  # created there and then delegated in the iam concerns file.
  #
  def role?(user)
    author?(user) || owner?(user) || validator?(user) || contributor?(user)
  end

  # return the manual reference or the internal reference
  def displayed_reference
    reference = field_value_value("reference")

    reference.present? ? reference : internal_reference
  end

  #
  # Returns the criticality delta between the two latest evaluations of the
  # risk. Returns nil if the risk has not been evaluated more than once.
  #
  # @return [Integer, Nil]
  #
  def criticality_delta
    last_eval, pre_last_eval = evaluations.order(created_at: :desc).first(2)
    return nil unless last_eval && pre_last_eval

    last_criticality = last_eval.field_value_evaluation(
      :criticality, last_eval.evaluation_system
    )
    pre_last_criticality = pre_last_eval.field_value_evaluation(
      :criticality, pre_last_eval.evaluation_system
    )

    return nil unless last_criticality.is_a?(AssessmentScaleRating)
    return nil unless pre_last_criticality.is_a?(AssessmentScaleRating)

    last_criticality.value - pre_last_criticality.value
  end

  # Defined in the Tracktable module, to mark actors that are updated for
  # timelogging and notifications.
  # TODO: they need to be defined when timetracking and logging are implemented
  # fully.
  #
  def mark_dirty_actor(actor); end
end
