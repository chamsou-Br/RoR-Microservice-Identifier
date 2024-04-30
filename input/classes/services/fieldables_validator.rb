# frozen_string_literal: true

# The is a validator on demand, aimed to validate the state of an entity with
# respect to its fields values. It considers presence of any fieldables,
# correct number according to for_field.field_type and required fields.
#
class FieldablesValidator
  # This method in the entry point to run all validations. To ensure that allr
  # errors are added to the ActiveModel::Errors, the method collects all the
  # boolean returns first, and then returns the equivalent to applying the
  # 'logical and' to the set.
  #
  def self.validated?(entity)
    return false unless entity.respond_to?(:fieldable_values)

    result = [any_fields?(entity),
              all_req_fields?(entity),
              redudant_fields?(entity)]
    result.exclude? false
  end

  def self.any_fields?(entity)
    if entity.fieldable_values.empty?
      entity.errors[:fieldable_values] <<
        "#{entity.class} must have at least one field value"
    end

    entity.fieldable_values.any?
  end

  # TODO: temporary method as the verification of required fields depends on
  # the state of the entity: before leaving a state, the required fields for
  # that stage, must have valid field values. Such requirements are sometimes
  # dependent on the form_section.
  # With refactoring, this needs disabling, to taylor to different section
  # names in different entities.
  #
  def self.all_req_fields?(entity)
    # entity.required_fields?("properties")
    entity
  end

  # This method verifies that the total number of field_values belonging to a
  # form_field, respect the allowed number, which depends on the field_type.
  #
  # 1. Gathers all form_fields related to the entity.
  # 2. Gathers the entity_standings array, which collects for each form_field,
  #   in a hash, its type, its name, an the number of the field values
  #   belonging to that form_field:
  #   [ { field_type:, field_name, field_value_count } ]
  # 3. Iterates through the array and adds an error if the number of
  # field_values exceeds that allowed according to the type of the form_field.
  #
  # @params entity
  # @return <Bool> true if entity.errors is empty.
  # @raise <NoMethodError> if entity or customer are nil
  #
  def self.redudant_fields?(entity)
    entity_form_fields = entity.customer.form_fields
                               .where(app_model: entity.class.to_s.downcase)

    count_by_form_field = entity.fieldable_values.group(:form_field_id).count

    entity_form_fields.each do |form_field|
      field_values_count = count_by_form_field[form_field.id] || 0

      next if %w[multi_select cascader].include?(form_field.field_type)
      next unless field_values_count > 1

      entity.errors[:fieldable_values] <<
        "can only have at most one field_value per form_field of "\
        "type '#{form_field.field_type}' with name '#{form_field.field_name}'"
    end

    entity.errors.empty?
  end
end
