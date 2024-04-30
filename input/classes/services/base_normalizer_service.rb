# frozen_string_literal: true

# This class is responsible for providing a template for descending classes
# Inherit a class from it and define an implementation for the find_value method
class BaseNormalizerService
  ATTRS = %i[email firstname lastname phone mobile_phone function service
             groups roles].freeze

  # @return [Hash] a hash with non-blank attributes (i.e. not nil, "" or [])
  def normalize
    ATTRS.each_with_object({}) do |attribute, result|
      value = find_value(attribute)
      result[attribute] = value unless value.blank?
    end
  end

  protected

  def find_value(_attribute)
    raise NotImplementedError
  end
end
