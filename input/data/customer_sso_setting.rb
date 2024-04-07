# frozen_string_literal: true

# == Schema Information
#
# Table name: customer_sso_settings
#
#  id                  :integer          not null, primary key
#  sso_url             :string(255)
#  slo_url             :string(255)
#  customer_setting_id :integer
#  cert_x509           :text(65535)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  email_key           :string(255)
#  firstname_key       :string(255)
#  lastname_key        :string(255)
#  idp_name            :string(255)
#  phone_key           :string(255)
#  service_key         :string(255)
#  function_key        :string(255)
#  mobile_phone_key    :string(255)
#  groups_key          :string(255)
#  roles_key           :string(255)
#

class CustomerSsoSetting < ApplicationRecord
  include Mappable

  belongs_to :customer_setting

  # Disabling this cop because `cert_x509` is an appropriate name and is the DB
  # column name
  # rubocop:disable Naming/VariableNumber
  validates :sso_url, :slo_url, :cert_x509, :idp_name,
            presence: true,
            unless: -> { customer_setting.customer.db_authen_strategy? }
  # rubocop:enable Naming/VariableNumber

  validates :email_key, :firstname_key, :lastname_key, presence: true

  after_initialize :set_default_values
  def filled?
    sso_url.present? && slo_url.present? && cert_x509.present? &&
      idp_name.present? && email_key.present? && firstname_key.present? &&
      lastname_key.present?
  end

  private

  def set_default_values
    self.email_key ||= "User.Email"
    self.lastname_key ||= "User.LastName"
    self.firstname_key ||= "User.FirstName"
  end
end
