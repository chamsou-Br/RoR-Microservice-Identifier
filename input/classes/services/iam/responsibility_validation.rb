# frozen_string_literal: true

#
# This class is part of the IAM service.
#
# It is in charge of validating a customer named responsibility, that is,
# ensuring that such responsibility exists in the responsibility configuration
# and that it belongs to the correct `model_level` or `module_level`.  The
# default configuration currently comes from `config/responsibility.yml`.
#
# The format of the responsibility name is expected to be:
#   `[model_level | module_level]_responsibility`.
#
class Iam::ResponsibilityValidation
  def initialize(
    module_level_info = Rails.configuration.responsibilities["module_level"],
    model_level_info = Rails.configuration.responsibilities["model_level"],
    entity_info = Rails.configuration.responsibilities["entity"]
  )
    @module_level_info = module_level_info
    @model_level_info = model_level_info
    @entity_info = entity_info
  end

  #
  # Returns true if the responsibility's full name is defined in the config for
  # the given affiliation type.
  #
  # @example
  #     defined_responsibility?("Customer", "risk_module_admin")
  #     defined_responsibility?("Customer", "risk_owner")
  #     defined_responsibility?("Risk", "owner")
  #
  # @return [Boolean]
  #
  def defined_responsibility?(affiliation_type, responsibility_name)
    responsibility_config_for(affiliation_type, responsibility_name).present?
  end

  #
  # Returns true if the responsibility's full name is found in the config.
  # It expects a name of a full responsibility belonging to a customer.
  #
  # @raise [RuntimeError] if `model_level` or `module_level` are blank.
  #
  # @param full_responsibility_name [String] the responsibility name to verify
  # @return [Boolean]
  #
  def valid_responsibility_name?(full_responsibility_name)
    responsibility, level = responsibility_level(full_responsibility_name)

    raise "This method only tests customer responsibilities" if level.blank?

    @module_level_info.dig(level, "responsibilities", responsibility) ||
      @model_level_info.dig(level, "responsibilities", responsibility)
  end

  #
  # Returns the `module_level` this responsibility belongs to, or `nil` if not
  # found.
  #
  # @param full_responsibility_name [String] the responsibility name to verify
  # @return [String] the parent `module_level`
  #
  def module_level(full_responsibility_name)
    responsibility, level = responsibility_level(full_responsibility_name)

    if @module_level_info.dig(level, "responsibilities", responsibility)
      level
    elsif @model_level_info.dig(level, "responsibilities", responsibility)
      @model_level_info[level]["parent_module"]
    end
  end

  # Given a full_responsibility_name find out if it is singular or plural,
  # based on the responsibilites configuration.
  #
  # @param affiliation_type [String]
  # @param responsibility_name [String]
  #   full responsibility name like `risk_module_admin`
  #
  # @raise [ArgumentError] if the responsibility is not defined for the
  # affiliation type.
  #
  # @return [Bool]
  #
  def singular?(affiliation_type, responsibility_name)
    responsibility_config = responsibility_config_for(affiliation_type,
                                                      responsibility_name)

    unless responsibility_config
      raise ArgumentError, "Responsibility #{responsibility_name} not defined for " +
                           affiliation_type
    end

    responsibility_config["singular"]
  end

  private

  # This method finds the level of the given responsibility.
  #
  # @param [String]
  # @return [Array<String>] array of two strings: simple_responsibility and
  #   level; level is empty string if responsibility is at entity level.
  #
  def responsibility_level(full_responsibility_name)
    responsibility_in_array = full_responsibility_name.rpartition("_")
    simple_responsibility = responsibility_in_array.last
    level = responsibility_in_array.first

    [simple_responsibility, level]
  end

  #
  # Returns the responsibility config of the given the responsibility's full
  # name for the given entity name or for the customer.
  #
  # @example
  #     responsibility_config_for("Customer", "risk_module_admin")
  #     responsibility_config_for("Customer", "risk_owner")
  #     responsibility_config_for("Risk", "owner")
  #
  # @return [Hash, nil] responsibility config like
  #   `{ required: true, singular: true }` or nil if it does not exist.
  #
  def responsibility_config_for(affiliation_type, responsibility_name)
    if affiliation_type == "Customer"
      responsibility, level = responsibility_level(responsibility_name)

      @module_level_info.dig(level, "responsibilities", responsibility) ||
        @model_level_info.dig(level, "responsibilities", responsibility)
    else
      @entity_info.dig(
        affiliation_type.underscore, "responsibilities", responsibility_name
      )
    end
  end
end
