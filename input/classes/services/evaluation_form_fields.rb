# frozen_string_literal: true

# This class is responsible for creating the predefined evaluation form fields
# and their field items for a customer enabling the risk module.
# * A complete set of evaluation fields belongs to an evaluation_system,
#   by which a risk is evaluated.
# * A customer may have several evaluation systems.
# * Presently, a risk can only have one evaluation_system, to be changed in a
#   future release.
#
class EvaluationFormFields
  ## FIELD ITEMS definitions
  DEFAULT_VALUES = {
    # Impact gravity
    impact: [
      { i18n_key: "major", color: "#EF4A53", value: 64 },
      { i18n_key: "important", color: "#EA6147", value: 16 },
      { i18n_key: "significant", color: "#F0BC0A", value: 4 },
      { i18n_key: "minor", color: "#58E78C", value: 1 },
      { i18n_key: "na", color: "#90A4AE", value: 0 }
    ],
    # Likelihood
    likelihood: [
      { i18n_key: "very_likely", color: "#EF4A53", value: 8 },
      { i18n_key: "likely", color: "#F49C24", value: 4 },
      { i18n_key: "possible", color: "#F0BC0A", value: 2 },
      { i18n_key: "unlikely", color: "#93D53C", value: 1 }
    ],
    # Criticality
    threat_level: [
      { i18n_key: "intolerable", color: "#EF4A53", value: 512 },
      { i18n_key: "severe", color: "#F49C24", value: 256 },
      { i18n_key: "moderate", color: "#F0BC0A", value: 64 },
      { i18n_key: "tolerable", color: "#93D53C", value: 16 },
      { i18n_key: "negligible", color: "#DFE6EC", value: 4 }
    ],
    # Response
    response_strategy: [
      { i18n_key: "accept_as_is", color: "#80DC67" },
      { i18n_key: "defer_processing", color: "#CCD8DF" },
      { i18n_key: "transfer", color: "#5C63E4" },
      { i18n_key: "mitigate", color: "#43D8E3" },
      { i18n_key: "remove", color: "#EF4A53" }
    ]
  }.freeze

  # This method enumerates the `field_item`s of the corresponding category,
  # named by item_name, to be added to the form_field upon creation.
  #
  # @param [String] item_name, the key of the `DEFAULT_VALUES` hash
  #   corresponding to the form_field category.
  #
  # @return [Array<Hash>]
  #   with keys: i18n_key, color, integer_value and sequence.
  #
  def self.one_level_items(item_name)
    DEFAULT_VALUES[item_name.to_sym].map.with_index do |info, index|
      info.merge(sequence: index)
    end
  end

  # Common options for app_model: evaluation
  # for form sections, impact_gravity, likelihood, criticality, response.
  EVAL_IMPACT_GRAVITY_OPTIONS = { app_model: :evaluation,
                                  form_section: :evaluation_impact_gravity,
                                  custom: false }.freeze

  EVAL_LIKELIHOOD_OPTIONS = { app_model: :evaluation,
                              form_section: :evaluation_likelihood,
                              group: :likelihood_group,
                              custom: false }.freeze

  EVAL_CRITICALITY_OPTIONS = { app_model: :evaluation,
                               form_section: :evaluation_criticality,
                               group: :criticality_group,
                               custom: false }.freeze

  EVAL_RESPONSE_OPTIONS = { app_model: :evaluation,
                            form_section: :evaluation_response,
                            custom: false,
                            required_state: :required_by_admin }.freeze

  RATING_FIELD = { field_type: :single_select,
                   linkable_type: "AssessmentScaleRating" }.freeze

  # The app_model evaluation form sections
  #
  # A risk can have more than one evaluation, but at the moment they are all of
  # the same evaluation system.
  #
  EVAL_IMPACT_GRAVITY_FIELDS = [
    # financial
    { field_name: "financial_impact",
      sequence: 0,
      required_state: :required_by_admin,
      group: :financial_group,
      **RATING_FIELD },
    # amount of financial impact
    { field_name: "financial_impact_amount",
      sequence: 1,
      field_type: :number,
      group: :financial_group },

    # financial
    # quality, performance, social, reputation, legal, human, environment
    # and total impacts
    #
    { field_name: "quality_impact", sequence: 2, **RATING_FIELD },
    { field_name: "performance_impact", sequence: 3, **RATING_FIELD },
    { field_name: "social_impact", sequence: 4, **RATING_FIELD },
    { field_name: "reputation_impact", sequence: 5, **RATING_FIELD },
    { field_name: "legal_impact", sequence: 6, **RATING_FIELD },
    { field_name: "human_impact", sequence: 7, **RATING_FIELD },
    { field_name: "environmental_impact", sequence: 8, **RATING_FIELD },
    # mark total impact as a required field
    { field_name: "total_impact", sequence: 9,
      required_state: :required_by_admin, **RATING_FIELD },
    # justification for overwriting the calculated total_impact
    { field_name: "severity_reason", sequence: 10, field_type: :text }
  ].freeze
  EVAL_LIKELIHOOD_FIELDS = [
    # likelihood scales
    { field_name: "likelihood", sequence: 0,
      required_state: :required_by_admin, **RATING_FIELD },
    # likelihood percentage
    { field_name: "likelihood_percentage", sequence: 1, field_type: :number }
  ].freeze

  EVAL_CRITICALITY_FIELDS = [
    { field_name: "criticality", sequence: 0,
      required_state: :required_by_admin, **RATING_FIELD },
    { field_name: "criticality_amount", sequence: 1, field_type: :number },
    { field_name: "criticality_calculated", sequence: 2,
      field_type: :number, visible: false }
  ].freeze
  EVAL_RESPONSE_FIELDS = [
    { field_name: "response_strategy", sequence: 0, field_type: :single_select,
      field_items_attributes: one_level_items("response_strategy") }
  ].freeze

  # This method creates the FormField, FieldItem and scale classes for the
  # defined defaults.
  #
  # @param [Customer]
  #
  # @raise [RuntimeError] if customer is nil
  #
  def self.create_defaults(customer)
    raise "Please provide a customer" unless customer

    create_form_fields(customer)
    create_scales(customer.evaluation_systems.first)
  end

  # This method creates the FormField, FieldItem records needed and according
  # to parameters defined in the hashes above:
  # * For impact, likelihood, threat_level, and response_strategy it creates the
  #   FormField records.
  # * For the response_strategy, it creates FieldItem records for the possible
  #   strategies.
  #
  # @param [Customer]
  #
  # @raise [ActiveRecord::RecordNotUnique] when attempting to create a
  #   duplicate FormField.
  #
  def self.create_form_fields(customer)
    # rubocop:disable Style/IfUnlessModifier
    if customer.evaluation_systems.any?
      customer.evaluation_systems.update_all(state: "archived")
    end
    # rubocop:enable Style/IfUnlessModifier

    evaluation_system = customer.evaluation_systems.create!(
      title: I18n.t("settings.risk.evaluation_system.default")
    )

    [
      { fields: EVAL_IMPACT_GRAVITY_FIELDS, opts: EVAL_IMPACT_GRAVITY_OPTIONS },
      { fields: EVAL_LIKELIHOOD_FIELDS, opts: EVAL_LIKELIHOOD_OPTIONS },
      { fields: EVAL_CRITICALITY_FIELDS, opts: EVAL_CRITICALITY_OPTIONS },
      { fields: EVAL_RESPONSE_FIELDS, opts: EVAL_RESPONSE_OPTIONS }
    ].each do |params|
      params[:fields].each do |f|
        evaluation_system.form_fields.create!(
          { customer_id: customer.id }.merge(f.merge(params[:opts]))
        )
      rescue ActiveRecord::RecordNotUnique
        puts "Record for #{f} already exists"
      end
    end
  end

  # This method creates the scale records as described in the hashes above.
  # * For each of impact, likelihood, threat_level, creates an AssessmentScale
  #   record.
  # * For impact, creates
  #   - a RiskImpact record for each of the impacts, and
  #   - a AssessmentScaleRating record for each impact rating.
  #
  # @param [EvaluationSystem]
  #
  # @raise To be defined
  #
  def self.create_scales(evaluation_system)
    %i[impact likelihood threat_level].each do |level|
      evaluation_system.scales << AssessmentScale.new(scale_type: level)
      DEFAULT_VALUES[level].each do |n|
        evaluation_system.send(
          "#{level}_scale"
        ).ratings << AssessmentScaleRating.new(n)
      end
    end

    evaluation_system.form_fields.each do |field_impact|
      next unless field_impact.field_name.match?(/impact$/)

      evaluation_system.impacts << RiskImpact.new(form_field: field_impact)
    end
  end

  # Return all predefined fields grouped by their model type
  #
  def self.predefined_form_fields
    {
      Evaluation.to_s => [EVAL_IMPACT_GRAVITY_FIELDS,
                          EVAL_LIKELIHOOD_FIELDS,
                          EVAL_CRITICALITY_FIELDS,
                          EVAL_RESPONSE_FIELDS].flatten
    }
  end
end
