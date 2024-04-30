# frozen_string_literal: true

# The class is responsible for processing the LDAP OAuth hash payload to
# produce a normalized hash of attributes in order to use UsersService for
# business logic
# Usage:
#   attrs = LdapNormalizerService.new(auth_hash, ldap_setting).normalize
# Values can be accessed in this format: attrs[:email], attrs[:firstname], etc.
#
class LdapNormalizerService < BaseNormalizerService
  def initialize(auth_hash, ldap_settings)
    super()
    @attributes = auth_hash.extra[:raw_info]
    @ldap_settings = ldap_settings
  end

  protected

  attr_reader :attributes, :ldap_settings

  # ldap auth hash contains values in the following format
  # :samaccountname=>["jdeveloper"] so we need to
  #  - find a mapping key from ldap settings of the current customer
  #  - downcase it and symbolize it
  #  - try to access auth hash with that key
  # @param attribute [Symbol] User attribute to get value for
  # @return [String, nil]
  #
  def find_value(attribute)
    key = ldap_settings.send("#{attribute}_key".to_sym)&.downcase&.to_sym
    attributes[key]&.first
  end
end
