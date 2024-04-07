# frozen_string_literal: true

class Signup
  extend ActiveModel::Naming
  extend ActiveModel::Translation
  include ActiveModel::Conversion
  include ActiveModel::Validations
  include ActiveModel::Validations::Callbacks

  def persisted?
    false
  end

  ATTRIBUTES = %i[firstname lastname email subdomain language function
                  contact_phone campaign time_zone_offset newsletter].freeze

  attr_accessor(*ATTRIBUTES)

  def initialize(attributes = {})
    ATTRIBUTES.each do |attribute|
      send("#{attribute}=", attributes[attribute])
    end
  end

  validates :firstname, presence: true
  validates :lastname, presence: true
  validates :email, format: /\A([\w.%+\-]+)@([\w\-]+\.)+(\w{2,})$\z/
  validates :subdomain, format: /\A[0-9A-Za-z-]+\z/
  validates :contact_phone, presence: true
  validates :contact_phone, format: /\A\+?[0-9 ]+\s?\z/,
                            unless: proc { |s| s.contact_phone.blank? }

  validate do
    unless customer.valid?
      errors.add(:subdomain, :taken) if customer.errors.include?(:url)
    end
  end

  before_validation { |signup| signup.subdomain = signup.subdomain.downcase }

  def customer
    @customer ||= Customer.new(
      subdomain: subdomain,
      language: language,
      contact_name: User::Name.new(firstname, lastname).full,
      contact_email: email,
      contact_phone: contact_phone,
      campaign: campaign,
      time_zone_offset: time_zone_offset,
      newsletter: newsletter
    )
  end

  def save
    return false unless valid?

    ActiveRecord::Base.transaction do
      DependencyFactoryService.create!(customer)
      invite_first_user
    end
    if customer.freemium?
      customer.update_attribute(:max_graphs_and_docs, 30)
      customer.update_attribute(:deactivated_at, 30.days.from_now)
      NotificationMailer.inform_salesman(@customer).deliver
    end
    true
  rescue Postmark::InvalidMessageError
    errors.add(:email, :failed_to_send)
    false
  end

  def invite_first_user
    customer.users.invite!(email: email, firstname: firstname,
                           lastname: lastname, language: language,
                           function: function) do |u|
      u.profile_type = "admin"
      u.improver_profile_type = "admin"
      u.time_zone = @customer.time_zone
      u.owner = true
    end
  end

  def self.authorized_remote_register?(self_url, remote_url)
    return true if remote_url&.start_with?(self_url)

    GeneralSetting.authorized_remote_registers.any? do |authorized_remote_register|
      remote_url&.start_with?(authorized_remote_register.general_setting_value)
    end
  end

  def self.authorized_token?(token)
    return false if token.blank?

    GeneralSetting.authorized_signup_tokens.any? do |authorized_token|
      token == authorized_token.general_setting_value
    end
  end
end
