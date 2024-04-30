# frozen_string_literal: true

# The class is responsible for creating risk predefined form fields with
# corresponding field items for the specified customer.
class RiskFormFields
  # Default values for field items in risk description
  DEFAULT_VALUES = {
    ## Properties
    access_level: [
      { i18n_key: "confidential", color: "#DFE6EC" },
      { i18n_key: "public", color: "#80DC67" }
    ],
    # The items in the risk_type have at most 3 levels of cascaders
    risk_type: [
      { i18n_key: "strategy", color: "#54CAEA" },
      { i18n_key: "projects", color: "#4975F2" },
      { i18n_key: "structure", color: "#F79B47" },
      { i18n_key: "management", color: "#47A5F9" },
      { i18n_key: "operations", color: "#3BD9AE" },
      { i18n_key: "resources", color: "#9468F6" },
      { i18n_key: "environment", color: "#C4D302" }
    ],
    cause_type: [
      { i18n_key: "method", color: "#43D8E3" },
      { i18n_key: "matter", color: "#47A5F9" },
      { i18n_key: "medium", color: "#58E78C" },
      { i18n_key: "material", color: "#4975F2" },
      { i18n_key: "workforce", color: "#E876C9" }
    ],

    # TODO: these two item colors are not revised
    mitigation_strategy_type: [
      { i18n_key: "protection", color: "#EA6147" },
      { i18n_key: "prevention", color: "#9468F6" }
    ]
  }.freeze

  LEVEL_TWO = {
    strategy: %i[development implementation],
    projects: %i[organization current],
    structure: %i[governance organizational geographic financial knowledge],
    management: %i[planning improvement internal_resources],
    operations: %i[realisation support technical],
    resources: %i[human material financial information stakeholder],
    environment: %i[market global criminal social natural]
  }.freeze

  LEVEL_THREE = {
    # sublevels strategy
    development: %i[national_policy analysis business social],
    implementation: %i[planning national regional communication],
    # sublevels projects
    organization: %i[economic_studies technical_studies contracts guidance
                     skills],
    # sublevels environemnt
    market: %i[dynamics competition technology norms],
    global: %i[political socio_eco_global socio_eco_local],
    criminal: %i[espionage terrorism crime],
    social: %i[local residential industrial],
    natural: %i[weather geology animal]
  }.freeze

  def self.one_level_items(item_name)
    DEFAULT_VALUES[item_name.to_sym].map.with_index do |info, index|
      info.merge(sequence: index, activated: true)
    end
  end

  # These arguments for field_item children, need the form_field_id to be
  # valid. Therefore, they need to be created after the form_field is created
  # so that such argument can be passed along.
  #
  def self.two_level_items(item_name, form_field_id)
    DEFAULT_VALUES[item_name.to_sym].map.with_index do |info, index|
      info.merge(
        sequence: index,
        activated: true,
        children_attributes: children_two_levels(info[:i18n_key], form_field_id)
      )
    end
  end

  def self.children_two_levels(item_name, form_field_id)
    LEVEL_TWO[item_name.to_sym].each_with_index.map do |info, index|
      if LEVEL_THREE[info]
        {
          activated: true,
          form_field_id: form_field_id,
          i18n_key: info.to_s,
          sequence: index,
          children_attributes: children_three_levels(info, form_field_id)
        }
      else
        {
          activated: true,
          form_field_id: form_field_id,
          i18n_key: info.to_s,
          sequence: index
        }
      end
    end
  end

  def self.children_three_levels(item_name, form_field_id)
    LEVEL_THREE[item_name].each_with_index.map do |info, index|
      {
        activated: true,
        form_field_id: form_field_id,
        i18n_key: info.to_s,
        sequence: index
      }
    end
  end

  ## Options at the app_model level and sometimes form_section
  #
  # Common options for app_model: risk
  # Common options per form section: properties, interactions, disasters
  RISK_PROPERTIES_OPTIONS = { app_model: :risk,
                              form_section: :risk_properties,
                              custom: false }.freeze
  RISK_CAUSE_EFFECT_OPTIONS = { app_model: :risk,
                                form_section: :risk_cause_effect,
                                custom: false }.freeze
  RISK_INTERACTIONS_OPTIONS = { app_model: :risk,
                                form_section: :risk_interactions,
                                custom: false }.freeze
  RISK_DISASTERS_OPTIONS = { app_model: :risk,
                             form_section: :risk_disasters,
                             custom: false }.freeze
  RISK_ACTION_PLAN_OPTIONS = { app_model: :risk,
                               form_section: :risk_action_plan,
                               custom: false }.freeze

  # Common options per form section: app_model: mitigation_strategy
  # Also known as risk control system or mechanism
  MITIGATION_STRATEGY_OPTIONS = {
    app_model: :mitigation_strategy,
    form_section: :mitigation_strategy_description,
    custom: false
  }.freeze

  ## FORM FIELDS
  ## Definition of fields per form section
  # The app_model risk form sections
  RISK_PROPERTIES_FIELDS = [
    { field_name: "title", sequence: 0, field_type: :text,
      required_state: :required_by_admin },
    { field_name: "access_level", sequence: 1, field_type: :radio_group,
      configurable: true,
      field_items_attributes: one_level_items(:access_level) },
    { field_name: "risk_type", sequence: 2, field_type: :cascader,
      required_state: :required_by_admin, configurable: true },
    { field_name: "description", sequence: 3, field_type: :text,
      required_state: :required_by_admin },
    { field_name: "internal_reference", sequence: 4, editable: false,
      field_type: :model_attribute, required_state: :preset_value },
    { field_name: "reference", sequence: 5, field_type: :text,
      required_state: :required_by_admin }
  ].freeze
  RISK_CAUSE_EFFECT_FIELDS = [
    { field_name: "cause_type", sequence: 0, field_type: :multi_select,
      configurable: true,
      field_items_attributes: one_level_items(:cause_type) },
    { field_name: "analysis", sequence: 1, field_type: :textarea },
    { field_name: "consequences", sequence: 2, field_type: :textarea }
  ].freeze
  RISK_INTERACTIONS_FIELDS = [
    { field_name: "affected_graphs", sequence: 0,
      field_type: :model_attribute },
    { field_name: "affected_documents", sequence: 1,
      field_type: :model_attribute },
    { field_name: "affected_roles", sequence: 2, field_type: :model_attribute },
    { field_name: "affected_depts", sequence: 3, field_type: :multi_select,
      configurable: true, visible: false },
    { field_name: "linked_risks", sequence: 4, field_type: :model_attribute },
    { field_name: "linked_opportunities", sequence: 5,
      field_type: :model_attribute },
    { field_name: "linked_projects", sequence: 6, field_type: :model_attribute }
  ].freeze
  RISK_DISASTERS_FIELDS = [
    { field_name: "events", sequence: 0, field_type: :model_attribute }
  ].freeze
  RISK_ACTION_PLAN_FIELDS = [
    { field_name: "acts", sequence: 0, field_type: :model_attribute },
    { field_name: "action_plans", sequence: 1, field_type: :model_attribute }
  ].freeze

  # The app_model mitigation_strategy form sections
  MITIGATION_STRATEGY_FIELDS = [
    { field_name: "mitigation_strategy_type", sequence: 0,
      field_type: :single_select, configurable: true,
      field_items_attributes: one_level_items(:mitigation_strategy_type) },
    { field_name: "description", sequence: 1, field_type: :text },
    { field_name: "linked_graphs", sequence: 2, field_type: :model_attribute },
    { field_name: "linked_documents", sequence: 3,
      field_type: :model_attribute },
    { field_name: "mitigation_strategy_attachments", sequence: 4,
      field_type: :model_attribute }
  ].freeze

  def self.create_form_fields(customer)
    create_risk_fields(customer)
    create_mitigation_strategy_fields(customer)
  end

  def self.create_risk_fields(customer)
    [
      { fields: RISK_PROPERTIES_FIELDS, opts: RISK_PROPERTIES_OPTIONS },
      { fields: RISK_CAUSE_EFFECT_FIELDS, opts: RISK_CAUSE_EFFECT_OPTIONS },
      { fields: RISK_INTERACTIONS_FIELDS, opts: RISK_INTERACTIONS_OPTIONS },
      { fields: RISK_DISASTERS_FIELDS, opts: RISK_DISASTERS_OPTIONS },
      { fields: RISK_ACTION_PLAN_FIELDS, opts: RISK_ACTION_PLAN_OPTIONS }
    ].each do |params|
      params[:fields].each do |f|
        customer.form_fields.create!(f.merge(params[:opts]))
      rescue ActiveRecord::RecordNotUnique
        puts "Record for #{f} already exists"
      end
    end

    field_items_risk_type
  end

  #
  # In the default settings, only the risk_type has cascading field_items of
  # many levels, hence this case specially handled here, as the children of
  # field_items need to have provided the form_field_id.
  #
  def self.field_items_risk_type
    ffrt = FormField.find_by(field_name: :risk_type)
    args = two_level_items(:risk_type, ffrt.id)

    ffrt.field_items.create!(args)
  end

  def self.create_mitigation_strategy_fields(customer)
    [
      { fields: MITIGATION_STRATEGY_FIELDS, opts: MITIGATION_STRATEGY_OPTIONS }
    ].each do |params|
      params[:fields].each do |f|
        customer.form_fields.create!(f.merge(params[:opts]))
      rescue ActiveRecord::RecordNotUnique
        puts "Record for #{f} already exists"
      end
    end
  end

  # Return all predefined fields grouped by their model type
  #
  def self.predefined_form_fields
    {
      Risk.to_s => [RISK_PROPERTIES_FIELDS,
                    RISK_CAUSE_EFFECT_FIELDS,
                    RISK_INTERACTIONS_FIELDS,
                    RISK_DISASTERS_FIELDS,
                    RISK_ACTION_PLAN_FIELDS].flatten,

      MitigationStrategy.to_s => [MITIGATION_STRATEGY_FIELDS].flatten

    }
  end
end
