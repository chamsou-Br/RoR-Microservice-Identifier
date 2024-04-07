# frozen_string_literal: true

# == Schema Information
#
# Table name: act_domain_settings
#
#  id                  :integer          not null, primary key
#  customer_setting_id :integer
#  label               :string(255)
#  color               :string(255)
#  activated           :boolean
#  by_default          :boolean          default(FALSE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  sequence            :integer
#

class ActDomainSetting < ApplicationRecord
  include Sequenceable

  scope :custom, -> { where(by_default: false) }

  belongs_to :customer_setting, optional: true

  has_many :act_domains, class_name: "ActDomain", foreign_key: :domain_id
  has_many :acts, through: :act_domains

  validates :label, presence: true, uniqueness: { scope: :customer_setting_id }

  before_destroy do |setting|
    unless setting.destroyable?
      errors.add :label, "setting linked!"
      raise ActiveRecord::Rollback
    end
  end

  def human_label
    return "" if label.blank?

    I18n.translate(label, scope: "activerecord.attributes.act_domain_setting.labels", default: label)
  end

  def destroyable?
    acts.empty?
  end
end
