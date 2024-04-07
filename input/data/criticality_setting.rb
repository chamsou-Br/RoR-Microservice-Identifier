# frozen_string_literal: true

# == Schema Information
#
# Table name: criticality_settings
#
#  id                  :integer          not null, primary key
#  customer_setting_id :integer
#  label               :string(255)
#  color               :string(255)
#  custom              :boolean          default(FALSE)
#  sequence            :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  activated           :boolean          default(TRUE)
#

class CriticalitySetting < ApplicationRecord
  belongs_to :customer_setting, optional: true

  # Return the text label associated with the criticality `id`, or a translated message for 'unassigned' of the id is
  # nil or 'invalid' if no criticality setting exists for the id.
  def self.label_for(id)
    if id.nil?
      I18n.t("activerecord.attributes.criticality_setting.unassigned")
    else
      CriticalitySetting.find_by(id: id)&.label || I18n.t("activerecord.attributes.criticality_setting.invalid")
    end
  end

  def serialize_this
    as_json(only: %i[id label color sequence activated])
  end
end
