# frozen_string_literal: true

# == Schema Information
#
# Table name: event_custom_properties
#
#  id               :integer          not null, primary key
#  customer_id      :integer
#  event_id         :integer
#  event_setting_id :integer
#  value            :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class EventCustomProperty < ApplicationRecord
  belongs_to :customer
  belongs_to :event
  belongs_to :event_setting

  # TODO: Refactor `self.save_custom_properties` into smaller methods
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.save_custom_properties(custom_fields, customer_id, event_id)
    custom_property_attributes = {}
    custom_property_attributes[:customer_id] = customer_id
    custom_property_attributes[:event_id] = event_id

    custom_fields.each do |key, value|
      event_setting = customer.event_settings.where(field_name: key).first
      custom_property_attributes[:event_setting_id] = event_setting.id

      custom_property = new(custom_property_attributes)

      # Oh boyyyyy
      case value
      when Array
        value.each do |v|
          custom_property.value = v[:id]
          custom_property.save

          # To instantiate another object for the loop
          custom_property = new(custom_property_attributes)
        end
      when Hash
        custom_property.value = value[:id]
        custom_property.save
      else
        custom_property.value = value
        custom_property.save
      end
    end
  end

  # TODO: Refactor `self.update_custom_properties` into smaller methods
  # rubocop:disable Metrics/PerceivedComplexity
  # There is a mess between instance and class methods...
  def self.update_custom_properties(custom_fields, event_id, customer_id)
    return if custom_fields.blank?

    custom_fields.each do |key, value|
      event_setting = customer.event_settings.where(field_name: key).first
      event_custom_properties = EventCustomProperty.where(event_setting_id: event_setting.id, event_id: event_id)

      if event_setting.field_type == "multi_select"
        event_custom_properties.delete_all

        value.each do |v|
          custom_property = new(customer_id: customer_id,
                                event_setting_id: event_setting.id,
                                event_id: event_id,
                                value: v[:id])
          custom_property.save
        end
      else

        event_custom_property = event_custom_properties.first

        new_value = if value.is_a?(Hash)
                      value[:id]
                    else
                      value
                    end

        if event_custom_property.nil?
          custom_property = new(customer_id: customer_id,
                                event_setting_id: event_setting.id,
                                event_id: event_id,
                                value: new_value)
          custom_property.save
        else
          event_custom_property.update(value: new_value)
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/PerceivedComplexity, Metrics/AbcSize: Assignment Branch Condition
end
