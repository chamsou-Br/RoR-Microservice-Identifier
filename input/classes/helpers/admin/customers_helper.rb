# frozen_string_literal: true

module Admin::CustomersHelper
  # @return ["freemium", "internal", "paid", "reserved", "trial"]
  def select_account_type(customer)
    if customer.internal?
      "internal"
    elsif customer.freemium?
      "freemium"
    elsif customer.paying?
      "paid"
    elsif customer.trial?
      "trial"
    elsif customer.reserved?
      "reserved"
    end
  end

  # @param ["freemium", "internal", "paid", "reserved", "trial"] type
  # @return [Hash{:freemium, :internal, :reserved, :trial => Boolean}]
  # @todo Raise argument error if given `type` is invalid
  # rubocop:disable Style/HashLikeCase
  def from_account_type(type)
    case type
    when "internal"
      { freemium: false, internal: true, reserved: false, trial: false }
    when "freemium"
      { freemium: true, internal: false, reserved: false, trial: false }
    when "paid"
      { freemium: false, internal: false, reserved: false, trial: false }
    when "trial"
      { freemium: false, internal: false, reserved: false, trial: true }
    when "reserved"
      { freemium: false, internal: false, reserved: true, trial: false }
    end
  end
  # rubocop:enable Style/HashLikeCase

  def oauth_logged_in?
    !session[:atoken].nil?
  end
end
