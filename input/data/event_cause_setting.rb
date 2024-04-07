# frozen_string_literal: true

# == Schema Information
#
# Table name: event_cause_settings
#
#  id                  :integer          not null, primary key
#  customer_setting_id :integer
#  label               :string(255)
#  activated           :boolean
#  by_default          :boolean          default(FALSE)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#

class EventCauseSetting < ApplicationRecord
  scope :custom, -> { where(by_default: false) }

  belongs_to :customer_setting, optional: true

  has_many :event_causes, class_name: "EventCause", foreign_key: :cause_id
  has_many :events, through: :event_causes

  validates :label, presence: true, uniqueness: { scope: :customer_setting_id }

  before_destroy do |setting|
    unless setting.destroyable?
      errors.add :label, "setting linked!"
      raise ActiveRecord::Rollback
    end
  end

  def human_label
    return "" if label.blank?

    I18n.translate(label, scope: "activerecord.attributes.event_cause_setting.labels", default: label)
  end

  # TODO: there is a serializer already at app/serializers/
  # but with different information. Need to do a manual serialiazer as other
  # parts (ElasticSearch) count on the default as_json method, so it cannot be
  # overwritten.
  def serialize_this
    as_json(only: %i[id label by_default])
  end

  def destroyable?
    events.empty?
  end
end
