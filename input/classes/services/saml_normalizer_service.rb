# frozen_string_literal: true

# The class is responsible for processing the SSO payload to produce a
# normalized hash of attributes in order to decouple UsersService from SAML
# attributes
# Usage:
#   attrs = SamlNormalizerService.new(idp_attrs, customer).normalize
# Values can be accessed like this: attrs[:email], attrs[:firstname], etc
#
class SamlNormalizerService < BaseNormalizerService
  def initialize(idp_attrs, current_customer)
    super()
    @attributes = idp_attrs.attributes
    @sso_settings = current_customer.settings.sso_settings
  end

  protected

  attr_reader :attributes, :sso_settings

  # Saml attributes hash contains values look like this
  #   "User.Email" => ["asomebody@domain.local"]
  # so we need to
  #  - find a mapping key from sso settings of the current customer
  #  - try to access attr hash with that key
  # @param attribute [Symbol] User attribute to get value for
  # @return [String, nil]
  #
  def find_value(attribute)
    key = sso_settings.send("#{attribute}_key".to_sym)
    attributes[key]&.first
  end
end
