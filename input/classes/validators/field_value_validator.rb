# frozen_string_literal: true

# This class validates a single FieldValue instance in two complimetary ways:
# * checks that only one and at least one of entiy and value exist
# * checks that the value or entity provided is consistent with the form_field
#   type this field_value belongs to.
#
class FieldValueValidator < ActiveModel::Validator
  def validate(record)
    @record = record
    field_value_membership
    field_type_consistency
    # TODO: here will go the validation for title fieldable
  end

  private

  def field_value_membership
    entity = find_entity

    # Only one of entity or value is to be present.
    return if [entity, @record.value.present?].one?

    @record.errors.add(
      :base,
      "Only and at least one of value or entity must be present (backend) "\
      "or defined (frontend). "\
      "No entity or value was provided for #{@record.field_name} "\
      "(#{@record.form_field_id}). "\
      "Values of a string should not be blank (empty string). "\
      "Remove the value if field is optional."
    )
  end

  # This method finds the entity object either from the instance or by
  # fetching it from the DB using class name (entity_type) and id.
  #
  # When the payload comes from graphql and the params are assigned as a
  # hash, there is no verification that entity_type and entity_id are
  # actually an object, and the field_value.entity does not exist.
  #
  # @return [nil] when either entity_type or entity_id are nil
  # @return [entity]
  #
  # @raise [NameError] when entity_type is not a class
  # @raise [ActiveRecord::RecordNotFound]
  #
  def find_entity
    return @record.entity if @record.entity
    return nil unless @record.entity_type && @record.entity_id

    @record.entity_type.constantize.find(@record.entity_id)
  end

  def field_type_consistency
    @type = @record.form_field&.field_type
    case @type
    when "text", "textarea"
      check_value
    when "single_select", "multi_select", "radio_group", "cascader"
      check_object
    when "date"
      check_date
    when "number"
      check_number
    else
      # TODO: these types need their fate to be defined. What does each of them
      # mean now after all the coding in the past several months.
      # multi_linkable: 6 <-- being replaced by Rails associations.
      # file: 7 <-- has not been used.
      # uni_linkable: 8 <-- being replaced by Rails associations.
      field_value_membership
    end
  end

  # Verifies that the value is not empty string nor nil. On failure, it adds
  # a message to the active model error, on key `value`.
  # The conditions to be fulfilled:
  # * value should be a String, which is the field data type
  # * entity must be nil, validated in `field_value_membership`
  #
  def check_value
    return unless @record.value.blank?

    add_errors(must_be: "a non-empty, non-blank string.")
  end

  # Verifies that the entity provided exists in the database. Assuming that it
  # is valid if it exists in the database.
  #
  # On failure, it adds a message to the active model error, on key `value`.
  # The conditions to be fulfilled:
  # * entity is a valid instance of an object in the database;
  # * value must be nil, validated in `field_value_membership`.
  #
  def check_object
    return if @record.entity&.persisted?

    add_errors(must_be: "Object must exists in the database.")
  end

  # Verifies that the value is an iso8601 date. On failure, it adds a messager
  # to the active model error, on key `value`.
  # The conditions to be fulfilled:
  # * value should be a date
  # * entity must be nil, validated in `field_value_membership`
  #
  def check_date
    return if DateTime.iso8601(@record.value)
  rescue TypeError, ArgumentError
    add_errors(must_be: "an iso8601 date.")
  end

  # Verifies that the value is numeric. On failure, it adds a message to the
  # active model error, on key `value`.
  # The conditions to be fulfilled:
  # * value should be convertable to a number
  # * entity must be nil, validated in `field_value_membership`
  #
  def check_number
    return if Float(@record.value)
  rescue TypeError, ArgumentError
    add_errors(must_be: "numeric.")
  end

  def add_errors(must_be:)
    @record.errors.add(
      :value,
      "The value of field value of type '#{@type}' must be #{must_be}"
    )
  end
end
