# frozen_string_literal: true

# == Schema Information
#
# Table name: event_validators
#
#  id           :integer          not null, primary key
#  validator_id :integer
#  event_id     :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  response     :string(255)
#  response_at  :datetime
#  comment      :string(255)
#

class EventValidator < ApplicationRecord
  belongs_to :orig_validator, class_name: "User", foreign_key: "validator_id"
  belongs_to :event
end
