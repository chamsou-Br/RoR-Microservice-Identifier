# frozen_string_literal: true

# == Schema Information
#
# Table name: lanes
#
#  id         :integer          not null, primary key
#  graph_id   :integer
#  x          :decimal(9, 4)
#  width      :decimal(9, 4)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  element_id :integer
#
# Indexes
#
#  index_lanes_on_element_id  (element_id)
#  index_lanes_on_graph_id    (graph_id)
#

class Lane < ApplicationRecord
  # attr_accessible :width, :x, :element_id

  belongs_to :graph
  belongs_to :element

  validates :x, :width, presence: true

  def self.delete_ids_not_in(js_lanes)
    available_ids = js_lanes.collect { |js_lane| js_lane["id"] }
    available_ids.delete_if { |id| id.nil? || id.is_a?(String) }
    if available_ids.empty?
      delete_all
    else
      where("id NOT IN (?)", available_ids).delete_all
    end
  end

  def self.create_or_update_from_json(js_lane)
    logger.debug("lane.create_or_update_from_json")
    if js_lane["id"].is_a?(Numeric)
      lane = find_or_create_by(id: js_lane["id"])
      lane.update_attributes(
        "x" => js_lane["x"],
        "width" => js_lane["width"],
        "element_id" => js_lane["element_id"]
      )
    else
      logger.debug "create the lane from js_lane : #{js_lane}"
      js_lane.delete_if { |key| key == "id" }
      lane = create do |a|
        a.x = js_lane["x"]
        a.width = js_lane["width"]
        a.element_id = js_lane["element_id"]
      end
    end

    lane
  end
end
