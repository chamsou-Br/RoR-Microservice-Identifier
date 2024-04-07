# frozen_string_literal: true

# == Schema Information
#
# Table name: general_settings
#
#  id                    :integer          not null, primary key
#  general_setting_key   :string(255)
#  general_setting_value :string(255)
#

class GeneralSetting < ApplicationRecord
  def self.authorized_remote_registers
    GeneralSetting.where(general_setting_key: "authorized_remote_register")
  end

  def self.authorized_signup_tokens
    GeneralSetting.where(general_setting_key: "authorized_signup_token")
  end

  def self.add_authorized_remote_register(remote_register)
    gs = GeneralSetting.new(general_setting_key: "authorized_remote_register",
                            general_setting_value: remote_register)
    gs.save
  end

  def self.remove_authorized_remote_register(remote_register)
    gss = GeneralSetting.where(general_setting_key: "authorized_remote_register",
                               general_setting_value: remote_register)
    gss.destroy_all
  end

  # TODO: Rename `self.updateField` to `self.update_field`
  # rubocop:disable Naming/MethodName
  def self.updateField(field_key, field_value)
    gss = GeneralSetting.where(general_setting_key: field_key)
    if gss.count <= 0
      # Creation
      gs = GeneralSetting.new(general_setting_key: field_key,
                              general_setting_value: field_value)
    else
      # update
      gs = gss.first
      gs.general_setting_value = field_value
    end
    gs.save
  end
  # rubocop:enable Naming/MethodName

  # TODO: Rename `self.getValueFromKey` to `self.get_value_from_key`
  # rubocop:disable Naming/MethodName
  def self.getValueFromKey(field_key)
    gss = GeneralSetting.where(general_setting_key: field_key)
    return "" if gss.count <= 0

    gss.first.general_setting_value
  end
  # rubocop:enable Naming/MethodName
end
