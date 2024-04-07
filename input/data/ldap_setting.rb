# frozen_string_literal: true

# == Schema Information
#
# Table name: ldap_settings
#
#  id                    :integer          not null, primary key
#  host                  :string(255)
#  port                  :integer          default(389)
#  uid                   :string(255)      default("sAMAccountName")
#  encryption            :integer          default("start_tls")
#  base_dn               :string(255)
#  bind_dn               :string(255)
#  encrypted_password    :string(255)
#  encrypted_password_iv :string(255)
#  customer_setting_id   :integer
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  email_key             :string(255)      default("userPrincipalName")
#  firstname_key         :string(255)      default("givenName")
#  lastname_key          :string(255)      default("sn")
#  phone_key             :string(255)
#  mobile_phone_key      :string(255)
#  function_key          :string(255)
#  service_key           :string(255)
#  groups_key            :string(255)
#  roles_key             :string(255)
#  server_name           :string(255)      default("My LDAP server"), not null
#  enabled               :boolean          default(FALSE), not null
#  filter                :string(255)      default(""), not null
#
# Indexes
#
#  index_ldap_settings_on_customer_setting_id    (customer_setting_id)
#  index_ldap_settings_on_encrypted_password_iv  (encrypted_password_iv) UNIQUE
#

class LdapSetting < ApplicationRecord
  include Mappable

  attr_encrypted :password, key: Rails.application.secrets.secret_key_base[0, 32]

  belongs_to :customer_setting

  enum encryption: { plain: 0, start_tls: 1, simple_tls: 2 }

  validates :server_name, :host, :port, :uid, :base_dn, presence: true
  validates :port, numericality: true
  validates :email_key, :firstname_key, :lastname_key, presence: true, allow_nil: true

  validate :check_disable_last_active, if: :will_save_change_to_enabled?

  before_destroy :check_delete_last_active

  scope :enabled, -> { where(enabled: true) }
  scope :for_settings, ->(id) { where(customer_setting_id: id) }

  def bind_credentials?
    bind_dn.present? && encrypted_password.present?
  end

  private

  def check_delete_last_active
    return unless customer_setting.ldap?

    active_servers = self.class.enabled.for_settings(customer_setting_id)
    return unless active_servers.count == 1 && active_servers.take == self

    errors.add(:base, I18n.t("settings.flash_msg_ldap.cannot_delete_last"))
    throw :abort
  end

  def check_disable_last_active
    return if enabled?
    return unless customer_setting.ldap?
    return if self.class.enabled.for_settings(customer_setting_id).count > 1

    errors.add(:base, I18n.t("settings.flash_msg_ldap.cannot_deactivate_last"))
  end
end
