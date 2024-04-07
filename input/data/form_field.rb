# frozen_string_literal: true

# rubocop: disable Layout/LineLength
# == Schema Information
#
# Table name: form_fields
#
#  id                   :integer          not null, primary key
#  customer_id          :integer
#  app_model            :integer          not null
#  form_section         :integer          not null
#  field_type           :integer          not null
#  label                :string(255)
#  field_name           :string(255)      not null
#  custom               :boolean
#  required             :boolean          default(FALSE)
#  sequence             :integer          not null
#  created_at           :datetime         not null
#  updated_at           :datetime         not null
#  evaluation_system_id :integer
#  group                :integer
#  editable             :boolean          default(TRUE)
#  visible              :boolean          default(TRUE)
#  linkable_type        :string(255)
#  configurable         :boolean          default(FALSE)
#  description          :text(65535)
#
# Indexes
#
#  index_form_fields_on_customer_app_model_eval_system_field_name  (customer_id,app_model,evaluation_system_id,field_name) UNIQUE
#  index_form_fields_on_customer_app_model_form_section            (customer_id,app_model,form_section)
#  index_form_fields_on_evaluation_system_id                       (evaluation_system_id)
#  unique_composite_index_on_form_fields                           (customer_id,app_model,form_section,evaluation_system_id,sequence) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (customer_id => customers.id)
#  fk_rails_...  (evaluation_system_id => evaluation_systems.id)
#

# rubocop:enable Layout/LineLength
#
# This class holds both custom and predefined fields for a particular form can
# be scoped by customer, module (Risk, ...) and form_type (Description,
# Properties, etc)
#
class FormField < ApplicationRecord
  # @!attribute [rw] description
  #   An optional description that can provide additional context about the
  #   meaning and/or purpose of a given field
  #   @return [String, nil]

  #
  # This callback sets configurable to true when custom is true on a new record.
  # Currently, this is only done on creation because the mutation SetFormSpecs
  # uses the record attributes to create a new record with freezes the original
  # record, not allowing its modification. Until that mutation is changed,
  # there will a validation on update.
  # TODO: change to before_save when mutation SetFormSpecs is modified.
  #
  before_create do
    self.configurable = true if custom
  end
  validate :custom_must_be_configurable, on: :update

  # global
  acts_as_list column: :sequence,
               scope: %i[customer_id app_model form_section
                         evaluation_system_id],
               top_of_list: 0

  # relations
  belongs_to :customer, inverse_of: :form_fields
  belongs_to :evaluation_system, inverse_of: :form_fields, optional: true

  has_one :impact,
          class_name: "RiskImpact",
          inverse_of: :form_field,
          dependent: :destroy

  has_many :field_items, dependent: :destroy
  has_many :field_values, dependent: :destroy
  accepts_nested_attributes_for :field_items, allow_destroy: true

  # @!group Scopes

  # Scopes for predefined fields based on app_model.
  scope :events_predef, -> { event.predefined }
  scope :acts_predef, -> { act.predefined }
  scope :audits_predef, -> { audit.predefined }

  scope :improver_predef, -> { event.or(act.or(audit)).predefined }
  scope :risk_predef, lambda {
    risk.or(evaluation.or(mitigation_strategy.or(processing))).predefined
  }
  scope :user_predef, -> { user.predefined }

  # @!method custom
  #   Scope form fields to those that are custom
  #   @return [ActiveRecord::Relation<FormField>]
  #   @!scope class
  scope :custom, -> { where(custom: true) }

  # "where" does not treat the enum symbols correctly.
  # enum field_type: { multi_linkable: 6, uni_linkable: 8, ... }
  scope :events_linkable, -> { events_predef.where(field_type: [6, 8]) }

  # @!method optional
  #   Scope form fields to those that are not required
  #   @return [ActiveRecord::Relation<FormField>]
  #   @!scope class
  scope :optional, -> { not_required }

  # @!method predefined
  #   Scope form fields to those that are predefined (not custom)
  #   @return [ActiveRecord::Relation<FormField>]
  #   @!scope class
  scope :predefined, -> { where(custom: false) }

  # @!method required
  #   Scope form fields to those that are required
  #   @return [ActiveRecord::Relation<FormField>]
  #   @!scope class
  scope :required, -> { required_by_admin.or(required_by_model) }

  # TODO: When the actor_attribute comes into effect, a new similar scope needs
  # to be created.
  #
  # @!method not_model_attr
  #   Scope form fields to those that are NOT of field_type: :model_attribute
  #   @return [ActiveRecord::Relation<FormField>]
  #   @!scope class
  # In the field_type enum: `model_attribute: 11`
  scope :not_model_attr, -> { where.not(field_type: 11) }

  # @!endgroup

  # Validations
  validates :app_model, :field_type, :form_section, presence: true
  validates :required_state, presence: true
  validates :custom, :editable, :visible, inclusion: { in: [true, false] }
  validates :field_name, presence: true,
                         uniqueness: { scope: %i[customer_id app_model
                                                 evaluation_system_id] }

  validate :must_be_visible_if_required

  # ENUMS
  # models that have custom fields
  enum app_model: {
    risk: 0,
    evaluation: 1,
    processing: 2,
    mitigation_strategy: 3,
    event: 4,
    act: 5,
    audit: 6,
    user: 7
  }

  # available field types
  enum field_type: {
    text: 0,
    single_select: 1,
    multi_select: 2,
    textarea: 3,
    radio_group: 4,
    cascader: 5,
    multi_linkable: 6,
    file: 7,
    uni_linkable: 8,
    date: 9,
    number: 10,
    model_attribute: 11,
    actor_attribute: 12
  }

  enum form_section: {
    # Risk Identification Block
    risk_properties: 0,
    risk_cause_effect: 18,
    risk_interactions: 5,
    risk_disasters: 6,
    risk_action_plan: 19,
    # Risk Mitigation Strategy Block
    mitigation_strategy_description: 7,
    # Risk Evaluation Block
    evaluation_impact_gravity: 1,
    evaluation_likelihood: 2,
    evaluation_criticality: 3,
    evaluation_response: 4,
    # Event Blocks
    event_description: 8,
    event_analysis: 9,
    event_action_plan: 10,
    # Act Blocks
    act_description: 11,
    act_realisation: 12,
    act_evaluation: 13,
    # Audit Blocks
    audit_description: 14,
    audit_plan: 15,
    audit_declared_events: 16,
    audit_synthesis: 17,
    # User Blocks
    user_personal_info: 20,
    user_extra_info: 21
  }

  # Groups for Risk Evaluation
  enum group: {
    financial_group: 0,
    likelihood_group: 1,
    criticality_group: 2
    # Any groups needed for Event?
  }

  enum value_editable_by: {
    noone: 0,
    user_admin_or_user: 1,
    user_admin: 2,
    current_user: 3
  }

  # This enum specifies the required_state of the value associated with this
  # form_field. It also dictates if the visibility toggle can be changed by an
  # admin in the settings (:not_required and :preset_value can be toggled) and
  # if a user can change the value in the entity card (:preset_value is not
  # changeable by the user).
  #
  enum required_state: {
    not_required: 0,
    required_by_admin: 1,
    required_by_model: 2,
    preset_value: 3
  }

  # Linkables to ignore as they cannot be enumerated per customer.
  IGNORE_LINKABLES =
    %w[EventAttachment ActAttachment AuditAttachment Task AuditElement
       AuditElementSubject].freeze

  # Where is this serialization being used?
  def serialize_this
    as_json(only: %i[id linkable_type app_model custom editable
                     field_name field_type form_section label required_state
                     sequence visible field_items])
  end

  #
  # Returns the default label, which is the translation derived from the human
  # attribute name of the `app_model` class and `field_name` for predefined
  # fields. Returns nil if this is a custom field, field name is also nil, or
  # the translation failed. Any kind of `I18n::ArgumentError` will be logged
  # via `I18n::MissingKeyLogger`.
  #
  # @return [String] The default label.
  #
  def default_label
    return if custom || field_name.nil?

    app_model&.capitalize&.constantize&.human_attribute_name(field_name)
  rescue I18n::ArgumentError => e
    I18n::MissingKeyLogger.log_the(e.message)
  end

  # Is the form field optional (not required)?
  #
  # @return [Boolean]
  #
  def optional?
    not_required?
  end

  def not_optional?
    required_by_admin? || required_by_model?
  end

  #
  # Is the form field predefined (not custom)?
  #
  # Predefined form fields are those automatically generated by the Pyx4
  # application as a basic requirement for describing each of the entity types.
  #
  # @return [Boolean]
  #
  def predefined?
    !custom?
  end

  private

  # Ensure the form field is visible if required or add an error otherwise
  #
  def must_be_visible_if_required
    return if preset_value? || optional? || (not_optional? && visible?)

    errors.add(:visibility, "Field must be visible if it is #{required_state}")
  end

  # The configurable flag designates if a form field's options can be changed.
  # This flag is used in the front-end to know if the modal to edit values is
  # to be shown, for example, to modify the field items of a custom form field.
  # The flag must be true if the field is custom.
  #
  # This method ensures that configurable is true for a custom field
  #
  def custom_must_be_configurable
    return if predefined? || (custom? && configurable?)

    errors.add(:configurable, "Field must be configurable if custom")
  end
end
