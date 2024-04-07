# frozen_string_literal: true

# == Schema Information
#
# Table name: package_lanes
#
#  id               :integer          not null, primary key
#  package_graph_id :integer
#  x                :decimal(9, 4)
#  width            :decimal(9, 4)
#  element_id       :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#

class PackageLane < ApplicationRecord
  belongs_to :package_graph

  def self.create_from(lane, package_graph)
    package_lane = PackageLane.new(
      lane.attributes.reject do |k, _|
        %w[id graph_id].include?(k)
      end
    ) do |e|
      e.package_graph = package_graph
    end
    package_lane.save
    package_lane
  end

  def self.create_lane_from(package_lane, graph)
    lane = Lane.new(
      package_lane.attributes.reject do |k, _|
        %w[created_at updated_at id package_graph_id].include?(k)
      end
    ) do |e|
      e.graph = graph
    end
    lane.save
    lane
  end
end
