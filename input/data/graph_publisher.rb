# frozen_string_literal: true

# == Schema Information
#
# Table name: graph_publishers
#
#  id           :integer          not null, primary key
#  graph_id     :integer
#  publisher_id :integer
#  published    :boolean
#  publish_date :datetime
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_graph_publishers_on_graph_id      (graph_id)
#  index_graph_publishers_on_publisher_id  (publisher_id)
#

class GraphPublisher < ApplicationRecord
  # Elasticsearch
  include SearchableGraphsPublisher

  validates :graph_id, uniqueness: true

  # @!attribute [rw] publisher
  #   @return [User]
  belongs_to :publisher, class_name: "User"

  # @!attribute [rw] graph
  #   @return [Graph]
  belongs_to :graph

  def self.duplicate_for(graph_duplicated, graph_template = nil)
    graph_template = graph_duplicated.parent if graph_template.nil?
    graph_publisher = graph_template.graph_publisher

    return if graph_publisher.nil?

    graph_publisher_duplicated = graph_publisher.dup
    graph_publisher_duplicated.graph = graph_duplicated
    graph_publisher_duplicated.published = nil
    graph_publisher_duplicated.publish_date = nil
    graph_publisher_duplicated.save
  end
end
