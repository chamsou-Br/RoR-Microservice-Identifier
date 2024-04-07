# frozen_string_literal: true

# == Schema Information
#
# Table name: event_type_settings
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

class EventTypeSetting < ApplicationRecord
  include Sequenceable

  # TODO: default_scopes are to be avoided. To delete.
  # Study the implications.
  default_scope { order(sequence: :asc) }
  scope :custom, -> { where(by_default: false) }
  belongs_to :customer_setting, optional: true
  has_many :events, foreign_key: :event_type_id
  validates :label, presence: true, uniqueness: { scope: :customer_setting_id }

  acts_as_list column: :sequence, scope: :customer_setting_id

  before_destroy do |setting|
    unless setting.destroyable?
      errors.add :label, "setting linked!"
      raise ActiveRecord::Rollback
    end
  end

  # TODO: there is a serializer already at app/serializers/
  # Need to do a manual serialiazer as other # parts (ElasticSearch)
  # count on the default as_json method, so it cannot be overwritten.
  def serialize_this
    as_json(only: %i[id label color sequence by_default])
  end

  def human_label
    return "" if label.blank?

    I18n.translate(label, scope: "activerecord.attributes.event_type_setting.labels", default: label)
  end

  def destroyable?
    events.empty?
  end

  def update_sequence(new_pos)
    update(sequence: new_pos)
  end
end
