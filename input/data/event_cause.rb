# frozen_string_literal: true

# == Schema Information
#
# Table name: event_causes
#
#  id       :integer          not null, primary key
#  event_id :integer
#  cause_id :integer
#
# Indexes
#
#  index_event_causes_on_cause_id               (cause_id)
#  index_event_causes_on_cause_id_and_event_id  (cause_id,event_id)
#  index_event_causes_on_event_id               (event_id)
#

class EventCause < ApplicationRecord
  belongs_to :event
  belongs_to :cause, class_name: "EventCauseSetting"
end
