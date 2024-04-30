# frozen_string_literal: true

# The class is responsible for processing the SSO payload to manage users
# The validation of the SSO response itself is meant to be done beforehand
#
# FIXME: This service seems to be unused. Instead, the ExternalUsersService is
# used and has almost the exact same implementation with more recent changes.
#
class SsoUsersService
  # @param idp_attrs [OneLogin::RubySaml::Attributes]
  #   User attributes coming via Identity Provider
  # @param current_customer [Customer] Current Customer record
  #
  def initialize(idp_attrs, current_customer)
    logger.info "------->idp_attrs: #{idp_attrs.inspect}"
    @attributes = idp_attrs.attributes
    @current_customer = current_customer
  end

  # Creates new or finds an existing user using SSO payload provided
  # @return [Hash]
  #   * :user [User, nil] Created, found or initialized User object
  #   * :error [Symbol, nil] Error type
  #   * :created_user_via_sso [Boolean, nil] Flag indicating that the User
  #       has been created
  #
  def load_saml_data
    # rubocop:disable Style/IfUnlessModifier
    unless Devise.email_regexp.match?(user_email)
      return { user: nil, error: :user_email_invalid }
    end
    return update_existing_user if existing_user

    if user_limit_reached?(new_user)
      return { user: new_user, error: :staff_is_full }
    end

    if new_user.save
      return { user: new_user, error: nil, created_user_via_sso: true }
    end
    # rubocop:enable Style/IfUnlessModifier

    { user: new_user, error: new_user.errors.keys.first.to_sym }
  end

  private

  attr_reader :attributes, :current_customer

  # general setup
  def new_user
    @new_user ||=
      current_customer.users.new(default_attributes.merge(tracked_attributes))
  end

  def existing_user
    @existing_user ||= current_customer.users.find_by(email: user_email)
  end

  def generated_password
    Devise.friendly_token.first(15)
  end


  # helpers

  def check_activation_status
    existing_user.deactivated? ? :user_deactivated : nil
  end

  def user_limit_reached?(user)
    !current_customer.can_add_user?(user)
  end

  # existing user update

  def update_existing_user
    if existing_user.update(tracked_attributes)
      { user: existing_user, error: check_activation_status }
    else
      { user: existing_user, error: existing_user.errors.keys.first.to_sym }
    end
  end

  # attributes management

  def default_attributes
    {
      email: user_email,
      language: current_customer.language,
      profile_type: "user",
      improver_profile_type: "user",
      time_zone: current_customer.time_zone,
      password: generated_password,
      skip_homepage: true
    }
  end

  def tracked_attributes
    {
      firstname: user_first_name,
      lastname: user_last_name
    }.merge(attributes_map)
  end

  # rubocop:disable Style/IfUnlessModifier
  def user_first_name
    if attributes[sso_settings.firstname_key].blank?
      return user_email.split("@").first
    end

    attributes[sso_settings.firstname_key].first
  end

  def user_last_name
    if attributes[sso_settings.lastname_key].blank?
      return user_email.split("@").first
    end

    attributes[sso_settings.lastname_key].first
  end
  # rubocop:enable Style/IfUnlessModifier

  # @param groups_list [Array] a list of groups to link to
  # @return [Array<Hash>]
  #   * :group_id An id of found/created group for the current customer
  def find_or_create_groups(groups_list)
    groups_list.map do |group_name|
      { group_id: current_customer.groups
                                  .find_or_create_by(title: group_name.strip)
                                  .id }
    end
  end

  # @param roles_list [Array] a list of roles to link to
  # @return [Array<Hash>]
  #   * :role_id An id of found/created role for the current customer
  def find_or_create_roles(roles_list)
    roles_list.map do |role_name|
      role = current_customer.roles.find_or_initialize_by(
        title: role_name.strip, type: "intern"
      )
      if role.new_record?
        # a role should always have an author (persisted user record)
        # a considered default is the instance owner or any active admin
        role.author =
          current_customer.owner || current_customer.active_power_users.first
        role.save
      end
      { role_id: role.id }
    end
  end

  # @return [Hash] Attributes hash compatible with ActiveRecord update/save
  # input format
  #   * :phone, :service, :mobile_phone, :function, :users_groups_attributes
  #
  def attributes_map
    %i[phone service mobile_phone function groups
       roles].reduce({}) do |sum, attr|
      received_value =
        attributes[sso_settings.send("#{attr}_key".to_sym)]&.first
      sum.merge(prepared_pair(received_value, attr))
    end
  end

  # @param received_value [String] Saml attribute value
  # @param attr [String] Saml attribute name
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  #
  def prepared_pair(received_value, attr)
    if received_value.blank? || parse(received_value).blank?
      {}
    elsif %i[phone mobile_phone].include?(attr)
      { attr.to_sym => received_value.gsub(/\s+|\+|-|\(|\)/, "") }
    elsif attr == :groups
      existing_user&.users_group&.delete_all
      { users_group_attributes: find_or_create_groups(parse(received_value)) }
    elsif attr == :roles
      existing_user&.roles_user&.delete_all
      { roles_user_attributes: find_or_create_roles(parse(received_value)) }
    else
      { attr.to_sym => received_value }
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  # @param unparsed [String]
  #   A string that contains one or several attributes (Group or Role)
  # @return [Array<String>] Group titles or Role titles
  #
  def parse(unparsed)
    unparsed.split(",").reject(&:blank?)
  end
end
