# frozen_string_literal: true

# The class is responsible for creating predefined form fields for a customer
# and corresponding field items as well
# class FormFieldCreator
class ImproverFormFields
  EVENT_DESC_OPTIONS = { app_model: :event, form_section: :event_description,
                         custom: false }.freeze
  EVENT_ANALYSIS_OPTIONS = { app_model: :event, form_section: :event_analysis,
                             custom: false }.freeze
  EVENT_ACTION_PLAN_OPTIONS = { app_model: :event,
                                form_section: :event_action_plan,
                                custom: false }.freeze
  ACT_DESC_OPTIONS = { app_model: :act, form_section: :act_description,
                       custom: false }.freeze
  ACT_EVAL_OPTIONS = { app_model: :act, form_section: :act_evaluation,
                       custom: false }.freeze
  ACT_REALISATION_OPTIONS = { app_model: :act, form_section: :act_realisation,
                              custom: false }.freeze
  AUDIT_DESC_OPTIONS = { app_model: :audit, form_section: :audit_description,
                         custom: false }.freeze
  AUDIT_PLAN_OPTIONS = { app_model: :audit, form_section: :audit_plan,
                         custom: false }.freeze
  AUDIT_EVENTS_OPTIONS = { app_model: :audit,
                           form_section: :audit_declared_events,
                           custom: false }.freeze
  AUDIT_SYNTHESIS_OPTIONS = { app_model: :audit, form_section: :audit_synthesis,
                              custom: false }.freeze

  DEFAULT_EVENT_DESC_FIELDS = [
    { field_name: :title, sequence: 0, field_type: :text,
      required_state: :required_by_admin },
    { field_name: :description, sequence: 1, field_type: :textarea,
      required_state: :required_by_admin },
    { field_name: :occurrence_at, sequence: 2, field_type: :date },
    { field_name: :reference, sequence: 3, field_type: :text },
    { field_name: :localisations, sequence: 4, field_type: :multi_linkable,
      linkable_type: "Localisation" },
    { field_name: :intervention, sequence: 5, field_type: :textarea },
    { field_name: :graphs_impacts, sequence: 6, field_type: :multi_linkable,
      linkable_type: "Graph" },
    { field_name: :documents_impacts, sequence: 7, field_type: :multi_linkable,
      linkable_type: "Document" },
    { field_name: :event_attachments, sequence: 8, field_type: :multi_linkable,
      linkable_type: "EventAttachment" }
  ].freeze

  DEFAULT_EVENT_ANALYSIS_FIELDS = [
    { field_name: :event_type, sequence: 0, field_type: :single_select,
      required_state: :required_by_admin, configurable: true },
    { field_name: :criticality, sequence: 1, field_type: :single_select,
      required_state: :required_by_admin, configurable: true },
    { field_name: :event_domains, sequence: 2, field_type: :multi_select,
      required_state: :required_by_admin, configurable: true },
    { field_name: :causes, sequence: 3, field_type: :multi_select,
      required_state: :required_by_admin, configurable: true },

    { field_name: :analysis, sequence: 4, field_type: :textarea },
    { field_name: :consequence, sequence: 5, field_type: :textarea },
    { field_name: :cost, sequence: 6, field_type: :text }
  ].freeze

  DEFAULT_EVENT_ACTION_PLAN_FIELDS = [
    { field_name: :acts, sequence: 0, field_type: :multi_linkable,
      linkable_type: "Act" }
  ].freeze

  DEFAULT_ACT_DESC_FIELDS = [
    { field_name: :title, sequence: 0, field_type: :text,
      required_state: :required_by_admin },
    { field_name: :description, sequence: 1, field_type: :textarea,
      required_state: :required_by_admin },
    { field_name: :act_type, sequence: 2, field_type: :single_select,
      required_state: :required_by_admin, configurable: true },
    { field_name: :estimated_start_at, sequence: 3, field_type: :date,
      required_state: :required_by_admin },
    { field_name: :estimated_closed_at, sequence: 4, field_type: :date,
      required_state: :required_by_admin },
    { field_name: :reference, sequence: 5, field_type: :text },
    { field_name: :objective, sequence: 6, field_type: :textarea },
    { field_name: :localisations, sequence: 7, field_type: :multi_linkable,
      linkable_type: "Localisation" },
    { field_name: :act_domains, sequence: 8, field_type: :multi_select,
      configurable: true },
    { field_name: :act_verif_type, sequence: 9, field_type: :single_select,
      configurable: true },
    { field_name: :act_eval_type, sequence: 10, field_type: :single_select,
      configurable: true },
    { field_name: :cost, sequence: 11, field_type: :textarea },
    { field_name: :act_attachments, sequence: 12, field_type: :multi_linkable,
      linkable_type: "ActAttachment" },
    { field_name: :graphs_impacts, sequence: 13, field_type: :multi_linkable,
      linkable_type: "Graph" },
    { field_name: :documents_impacts, sequence: 14,
      field_type: :multi_linkable, linkable_type: "Document" }
    # Also has 'provenances' (sources) which are the Events that link to the
    # Act (display only). We don't want to create a FormField / FieldValue
    # for it here lest we end up modeling the relation in two places using
    # two disconnected datasets.
  ].freeze

  DEFAULT_ACT_EVAL_FIELDS = [
    # The 'efficiency' field is a select among enum values `Act.efficiency`
    # which does not have corresponding settings models.
    #
    { field_name: :efficiency, sequence: 0, field_type: :single_select,
      required_state: :required_by_admin },
    { field_name: :check_result, sequence: 1, field_type: :textarea,
      required_state: :required_by_admin }
  ].freeze

  DEFAULT_ACT_REALISATION_FIELDS = [
    { field_name: :tasks, sequence: 0, field_type: :multi_linkable,
      linkable_type: "Task" },
    # progress is to replace the ill-named achievement field
    { field_name: :progress, sequence: 1, field_type: :number }
  ].freeze

  DEFAULT_AUDIT_DESC_FIELDS = [
    { field_name: :title, sequence: 0, field_type: :text,
      required_state: :required_by_admin },
    { field_name: :object, sequence: 1, field_type: :textarea,
      required_state: :required_by_admin },
    { field_name: :audit_type, sequence: 2, field_type: :single_select,
      required_state: :required_by_admin, configurable: true },
    { field_name: :estimated_start_at, sequence: 3, field_type: :date,
      required_state: :required_by_admin },
    { field_name: :estimated_closed_at, sequence: 4, field_type: :date,
      required_state: :required_by_admin },
    { field_name: :reference, sequence: 5, field_type: :text },
    { field_name: :audit_scopes, sequence: 6, field_type: :multi_select,
      configurable: true },
    { field_name: :localisations, sequence: 7, field_type: :multi_linkable,
      linkable_type: "Localisation" },
    { field_name: :audit_attachments, sequence: 8, field_type: :multi_linkable,
      linkable_type: "AuditAttachment" }
  ].freeze

  DEFAULT_AUDIT_PLAN_FIELDS = [
    { field_name: :audit_elements, sequence: 0, field_type: :multi_linkable,
      linkable_type: "AuditElement" }
  ].freeze

  DEFAULT_AUDIT_EVENTS_FIELDS = [
    { field_name: :events, sequence: 0, field_type: :multi_linkable,
      linkable_type: "Event" }
  ].freeze

  DEFAULT_AUDIT_SYNTHESIS_FIELDS = [
    { field_name: :synthesis, sequence: 0, field_type: :textarea }
  ].freeze

  # Declaration of default colors for predef field items
  DEFAULT_COLORS = {
    event_type: {
      non_compliance: "#EA6147",
      sensitive_point: "#9468F6",
      lead_of_improvement: "#54CAEA",
      strong_point: "#F79B47",
      work_accident: "#EF4A53",
      customer_complaint: "#E876C9"
    },
    event_domains: {
      quality: "#4975F2",
      security: "#EF4A53",
      environment: "#93D53C"
    },
    criticality: {
      major: "#EF4A53",
      important: "#F79B47",
      notable: "#F0BC0A",
      minor: "#58E78C"
    },
    causes: {
      personal: "#9468F6",
      material: "#4975F2",
      machine: "#47A5F9",
      method: "#43D8E3",
      management: "#58E78C",
      environment: "#93D53C"
    },
    act_type: {
      preventive: "#F79B47",
      corrective: "#80DC67",
      improvement: "#FC77A8"
    },
    act_domains: {
      quality: "#4975F2",
      security: "#EF4A53",
      environment: "#93D53C"
    },
    act_verif_type: {
      control: "#F0BC0A",
      audit: "#F79B47"
    },
    act_eval_type: {
      indicator: "#47A5F9",
      audit: "#F79B47",
      management_feedback: "#58E78C",
      customer_feedback: "#E876C9"
    },
    efficiency: {
      not_checked: "#90A4AE",
      efficient: "#80DC67",
      not_efficient: "#EF4A53"
    },
    audit_scopes: {
      system: "#F79B47",
      process: "#43D8E3",
      procedure: "#4975F2",
      product: "#E876C9",
      project: "#EA6147"
    },
    audit_type: {
      internal: "#43D8E3",
      external: "#58E78C",
      certification: "#93D53C",
      diagnostic: "#F0BC0A",
      evaluation: "#FB8B5B"
    }
  }.freeze

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def self.create_form_fields(customer)
    # Doing any processing is risky as there are improver predef fields in
    # existence. Customer had probably improver enabled and was switched off.
    # Returning if that is case.
    return [{}, {}] if customer.form_fields.improver_predef.any?

    # Faster than find_by() in a loop to link FieldItems.
    field_item_cache = {}

    # Track created IDs for 'fake' settings created from enums.
    enum_field_ids = {}
    enum_field_ids["efficiency"] = {}

    # Create default form fields for all app models and form sections.
    [
      { fields: DEFAULT_EVENT_DESC_FIELDS, opts: EVENT_DESC_OPTIONS },
      { fields: DEFAULT_EVENT_ANALYSIS_FIELDS, opts: EVENT_ANALYSIS_OPTIONS },
      { fields: DEFAULT_EVENT_ACTION_PLAN_FIELDS,
        opts: EVENT_ACTION_PLAN_OPTIONS },
      { fields: DEFAULT_ACT_DESC_FIELDS, opts: ACT_DESC_OPTIONS },
      { fields: DEFAULT_ACT_EVAL_FIELDS, opts: ACT_EVAL_OPTIONS },
      { fields: DEFAULT_ACT_REALISATION_FIELDS, opts: ACT_REALISATION_OPTIONS },
      { fields: DEFAULT_AUDIT_DESC_FIELDS, opts: AUDIT_DESC_OPTIONS },
      { fields: DEFAULT_AUDIT_PLAN_FIELDS, opts: AUDIT_PLAN_OPTIONS },
      { fields: DEFAULT_AUDIT_EVENTS_FIELDS, opts: AUDIT_EVENTS_OPTIONS },
      { fields: DEFAULT_AUDIT_SYNTHESIS_FIELDS, opts: AUDIT_SYNTHESIS_OPTIONS }
    ].each do |params|
      params[:fields].each do |f|
        customer.form_fields.create!(f.merge(params[:opts]))
      rescue ActiveRecord::RecordNotUnique
        puts "Record for #{f} already exists"
      end
    end

    # At the moment this data migration has to consider existing setting and
    # the creation of such setting for new customer. In a hopefully near
    # future, these setting models shall not exist, and data migration will no
    # longer be needed. When that is that case. all we need is the creation of
    # field items form DEFAULT_COLORS` hash. For now, will use a conditional.
    #
    # Create field_items for form_fields with single and multi selects,
    # based on definitions in the DEFAULT_COLORS hash, or settings.
    #
    [Event, Act, Audit].each do |model|
      model_str = model.to_s.downcase
      predef_fields = customer.form_fields.send "#{model_str}s_predef"

      predef_fields.each do |ff|
        next unless %w[multi_select single_select].include? ff.field_type

        if customer.events.empty? &&
           customer.acts.empty? &&
           customer.audits.empty?
          # Customer new to improver
          DEFAULT_COLORS[ff.field_name.to_sym].each_with_index do |info, index|
            new_item = FieldItem.new(
              activated: true,
              i18n_key: info.first.to_s,
              color: info.last,
              sequence: index
            )
            ff.field_items << new_item
          end
        else
          # Customer has existing improver elements, meaning one of these:
          # * customer is being migrated to improver 2;
          # * customer was previously improver and was switched off;
          # * the improver elements were created before the Improver 2.0.
          #
          field_item_cache[ff.field_name] = {}
          has_sequence = model != Audit && ff.field_name != "causes"
          has_color = ff.field_name != "causes"

          settings =
            if model == Act && ff.field_name == "efficiency"
              Act.efficiencies.map do |key, value|
                enum_field_ids["efficiency"][key] = SecureRandom.uuid
                OpenStruct.new(
                  id: enum_field_ids["efficiency"][key],
                  label: key,
                  activated: true,
                  sequence: value
                )
              end
            else
              customer.send(ff.field_name)
            end

          settings.each do |s|
            label_or_key = if snakey?(s.label)
                             { i18n_key: s.label }
                           else
                             { label: s.label }
                           end

            default_color = DEFAULT_COLORS[ff.field_name.to_sym][s.label.to_sym]
            new_item = FieldItem.new(
              {
                activated: s.activated || true,
                color: has_color ? (s.color || default_color) : default_color,
                sequence: has_sequence ? s.sequence : nil
              }.merge(label_or_key)
            )

            field_item_cache[ff.field_name][s.id] = new_item
            ff.field_items << new_item
          end
        end
      end
    end

    [field_item_cache, enum_field_ids]
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  ##
  # Return all predefined fields grouped by their model type
  #
  def self.predefined_form_fields
    {
      Event.to_s => [DEFAULT_EVENT_DESC_FIELDS,
                     DEFAULT_EVENT_ANALYSIS_FIELDS,
                     DEFAULT_EVENT_ACTION_PLAN_FIELDS].flatten,

      Act.to_s => [DEFAULT_ACT_DESC_FIELDS,
                   DEFAULT_ACT_EVAL_FIELDS,
                   DEFAULT_ACT_REALISATION_FIELDS].flatten,

      Audit.to_s => [DEFAULT_AUDIT_DESC_FIELDS,
                     DEFAULT_AUDIT_PLAN_FIELDS,
                     DEFAULT_AUDIT_EVENTS_FIELDS,
                     DEFAULT_AUDIT_SYNTHESIS_FIELDS].flatten
    }
  end

  def self.snakey?(str)
    (str == str.downcase) && str.exclude?(" ")
  end
end
