# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_settings
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

class AuditSetting < ApplicationRecord
  include SequenceableByCustomer

  enum form_type: { audit_description: 0, audit_plan: 1, audit_declared_events: 2 }
  enum field_type: { text: 0, radio: 1, multi_select: 2, textarea: 3, file: 4 }

  has_many :select_items, dependent: :destroy, class_name: "ActSettingSelectItems"

  belongs_to :customer
end
