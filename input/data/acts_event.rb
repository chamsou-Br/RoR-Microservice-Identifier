# frozen_string_literal: true

# == Schema Information
#
# Table name: acts_events
#
#  id         :integer          not null, primary key
#  act_id     :integer
#  event_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_acts_events_on_act_id               (act_id)
#  index_acts_events_on_act_id_and_event_id  (act_id,event_id)
#  index_acts_events_on_event_id             (event_id)
#

class ActsEvent < ApplicationRecord
  belongs_to :act
  belongs_to :event

  after_commit on: %i[create destroy] do |act_event|
    act_event.act.__elasticsearch__.update_document
  end
end
