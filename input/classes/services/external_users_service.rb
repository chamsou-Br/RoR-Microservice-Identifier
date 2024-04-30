# frozen_string_literal: true

# The class is responsible for processing the SSO payload to manage users
# The validation of the SSO response itself is meant to be done beforehand
class ExternalUsersService
  # @param normalized_attrs [Hash] User attributes coming via Identity Provider
  #                                (normalized to a Hash)
  # @param current_customer [Customer] Current Customer record
  def initialize(normalized_attrs, current_customer)
    @attributes = normalized_attrs
    @current_customer = current_customer
  end

  # Creates new or finds an existing user using SSO payload provided
  # @return [Hash]
  #   * :user [User, nil] Created, found or initialized User object
  #   * :error [Symbol, nil] Error type
  #   * :created_user [Boolean, nil] Flag indicating that the User is created
  #
  def process_data
    # rubocop:disable Style/IfUnlessModifier
    unless Devise.email_regexp.match?(user_email)
      return { user: nil, error: :user_email_invalid }
    end

    if cannot_reactivate?(existing_user)
      return { user: existing_user, error: :staff_is_full }
    end

    return update_existing_user if existing_user

    if user_limit_reached?(new_user)
      return { user: new_user, error: :staff_is_full }
    end
    # rubocop:enable Style/IfUnlessModifier

    return { user: new_user, error: nil, created_user: true } if new_user.save

    { user: new_user, error: new_user.errors.keys.first.to_sym }
  end

  private

  attr_reader :attributes, :current_customer

  # general setup
  def new_user
    @new_user ||= current_customer.users.new(
      new_user_attributes.merge(attributes_to_update)
    )
  end

  def existing_user
    @existing_user ||= current_customer.users.find_by(email: user_email)
  end

  def generated_password
    Devise.friendly_token.first(15)
  end

  def sso_settings
    current_customer.settings.sso_settings
  end

  def user_email
    attributes[:email]
  end

  # helpers

  def cannot_reactivate?(user)
    user&.deactivated? && user_limit_reached?(user)
  end

  def user_limit_reached?(user)
    !current_customer.can_add_user?(user)
  end

  # existing user update

  def update_existing_user
    if existing_user.update(attributes_to_update)
      { user: existing_user, error: nil }
    else
      { user: existing_user, error: existing_user.errors.keys.first.to_sym }
    end
  end

  # attributes management

  def new_user_attributes
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

  def attributes_to_update
    # we want to make sure user is active when they come from SSO
    # and at this point we already checked for user limits
    { deactivated: false }.merge(tracked_attributes)
  end

  def tracked_attributes
    {
      firstname: user_first_name,
      lastname: user_last_name
    }.merge(optional_attributes)
  end

  def user_first_name
    return user_email.split("@").first if attributes[:firstname].nil?

    attributes[:firstname]
  end

  def user_last_name
    return user_email.split("@").first if attributes[:lastname].nil?

    attributes[:lastname]
  end

  # @param groups_list [Array] a list of groups to link to
  # @return Array<Hash>
  #   * :group_id An id of found/created group for the current customer
  def find_or_create_groups(groups_list)
    groups_list.map do |group_name|
      { group_id: current_customer.groups
                                  .find_or_create_by(title: group_name.strip)
                                  .id }
    end
  end

  # @param roles_list [Array] a list of roles to link to
  # @return Array<Hash>
  #   * :role_id An id of found/created role for the current customer
  def find_or_create_roles(roles_list)
    roles_list.map do |role_name|
      role = current_customer.roles.find_or_initialize_by(
        title: role_name.strip, type: "intern"
      )
      if role.new_record?
        # a role should always have an author (persisted user record)
        # a considered default is the instance owner or any active admin
        role.author = current_customer.owner ||
                      current_customer.active_power_users.first
        role.save
      end
      { role_id: role.id }
    end
  end

  # @return [Hash] Attributes hash compatible with ActiveRecord update/save
  # input format:
  #   * :phone, :service, :mobile_phone, :function, :users_groups_attributes
  #
  def optional_attributes
    %i[phone service mobile_phone function groups
       roles].reduce({}) do |sum, attr|
      received_value = attributes[attr]
      sum.merge(prepared_pair(received_value, attr))
    end
  end

  # @param received_value [String] Saml attribute value
  # @param attr [String, Symbol] Saml attribute name
  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
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

  # @param unparsed [String] A string that contains one or several attributes
  #                         (Group or Role)
  # @return [Array<String>] Group titles or Role titles
  def parse(unparsed)
    unparsed.split(",").reject(&:blank?)
  end
end
