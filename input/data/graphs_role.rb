# frozen_string_literal: true

# == Schema Information
#
# Table name: graphs_roles
#
#  id         :integer          not null, primary key
#  role_id    :integer
#  graph_id   :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_graphs_roles_on_graph_id              (graph_id)
#  index_graphs_roles_on_graph_id_and_role_id  (graph_id,role_id)
#  index_graphs_roles_on_role_id               (role_id)
#

class GraphsRole < ApplicationRecord
  belongs_to :role
  belongs_to :graph

  def self.duplicate_for(graph_duplicated, graph_template = nil)
    graph_template = graph_duplicated.parent if graph_template.nil?
    graph_template.graphs_roles.each do |graph_role|
      graphs_role_duplicated = graph_role.dup
      graphs_role_duplicated.graph = graph_duplicated
      graphs_role_duplicated.save
    end
  end
end
