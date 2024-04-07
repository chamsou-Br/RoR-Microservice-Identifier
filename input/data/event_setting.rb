# frozen_string_literal: true

# == Schema Information
#
# Table name: event_settings
#
#  id           :integer          not null, primary key
#  customer_id  :integer
#  mandatory    :boolean          default(TRUE)
#  label        :string(64)
#  active       :boolean          default(TRUE)
#  sequence     :integer
#  field_name   :string(255)      not null
#  form_type    :integer
#  custom_field :boolean          default(TRUE)
#  field_type   :integer          default("text")
#  created_at   :datetime
#  updated_at   :datetime
#

class EventSetting < ApplicationRecord
  include SequenceableByCustomer

  enum form_type: { event_description: 0, event_analysis: 1, event_action_plan: 2 }
  enum field_type: { text: 0, radio: 1, multi_select: 2, textarea: 3, file: 4 }

  has_many :select_items, dependent: :destroy, class_name: "EventSettingSelectItems"
  has_many :event_custom_properties # Values of custom fields for an event

  belongs_to :customer

  scope :active, -> { where(active: true) }
  scope :mandatory, -> { active.where(mandatory: true) }
  scope :optional, -> { active.where(mandatory: false) }
  scope :custom_fields, -> { active.where(custom_field: true) }
  scope :standard_fields, -> { active.where(custom_field: false) }
  scope :description, -> { active.where(form_type: 0) }
  scope :analysis, -> { active.where(form_type: 1) }
end
