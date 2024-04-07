# frozen_string_literal: true

# == Schema Information
#
# Table name: event_setting_select_items
#
#  id               :integer          not null, primary key
#  label            :string(64)
#  sequence         :integer
#  event_setting_id :integer
#  activated        :boolean          default(TRUE)
#  created_at       :datetime
#  updated_at       :datetime
#

class EventSettingSelectItems < ApplicationRecord
  belongs_to :event_setting, optional: true
end
