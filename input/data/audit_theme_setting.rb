# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_theme_settings
#
#  id                  :integer          not null, primary key
#  customer_setting_id :integer
#  label               :string(255)
#  color               :string(255)
#  activated           :boolean
#  by_default          :boolean          default(FALSE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class AuditThemeSetting < ApplicationRecord
  scope :custom, -> { where(by_default: false) }

  belongs_to :customer_setting, optional: true

  has_many :audit_themes, class_name: "AuditTheme", foreign_key: :theme_id
  has_many :audits, through: :audit_themes

  validates :label, presence: true, uniqueness: { scope: :customer_setting_id }

  before_destroy do |setting|
    unless setting.destroyable?
      errors.add :label, "setting linked!"
      raise ActiveRecord::Rollback
    end
  end

  def human_label
    return "" if label.blank?

    I18n.translate(label, scope: "activerecord.attributes.audit_theme_setting.labels",
                          default: label)
  end

  def destroyable?
    audits.empty?
  end
end
