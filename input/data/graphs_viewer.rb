# frozen_string_literal: true

# == Schema Information
#
# Table name: graphs_viewers
#
#  graph_id    :integer
#  viewer_id   :integer
#  viewer_type :string(255)
#  id          :integer          not null, primary key
#
# Indexes
#
#  index_graphs_viewers_on_graph_id                   (graph_id)
#  index_graphs_viewers_on_viewer_id_and_viewer_type  (viewer_id,viewer_type)
#

class GraphsViewer < ApplicationRecord
  # Elasticsearch
  include SearchableGraphsViewer

  belongs_to :viewer, polymorphic: true
  belongs_to :graph

  def self.duplicate_for(graph_duplicated, graph_template = nil)
    graph_template = graph_duplicated.parent if graph_template.nil?
    graph_template.graphs_viewers.each do |graph_viewer|
      graph_viewer_duplicated = graph_viewer.dup
      graph_viewer_duplicated.graph = graph_duplicated
      graph_viewer_duplicated.save
    end
  end
end
