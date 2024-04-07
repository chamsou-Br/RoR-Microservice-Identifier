# frozen_string_literal: true

# == Schema Information
#
# Table name: graphs_approvers
#
#  id          :integer          not null, primary key
#  graph_id    :integer
#  approver_id :integer
#  approved    :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  comment     :string(765)
#  historized  :boolean          default(FALSE), not null
#
# Indexes
#
#  index_graphs_approvers_on_approver_id               (approver_id)
#  index_graphs_approvers_on_approver_id_and_graph_id  (approver_id,graph_id)
#  index_graphs_approvers_on_graph_id                  (graph_id)
#

class GraphsApprover < ApplicationRecord
  ## Elasticsearch
  include SearchableGraphsApprover

  belongs_to :approver, class_name: "User"
  belongs_to :graph

  scope :current, -> { where(historized: false) }
  scope :pending, -> { where(historized: false, approved: false) }

  before_save :check_comment

  def self.duplicate_for(graph_duplicated, graph_template = nil)
    graph_template = graph_duplicated.parent if graph_template.nil?
    graph_template.graphs_approvers.current.each do |graph_approver|
      graph_approver_duplicated = graph_approver.dup
      graph_approver_duplicated.graph = graph_duplicated
      graph_approver_duplicated.approved = false
      graph_approver_duplicated.comment = nil
      graph_approver_duplicated.save
    end
  end

  def check_comment
    return unless !comment.nil? && comment.length > graph.comment_wf_max_length

    self.comment = comment[0..(graph.comment_wf_max_length - 1)]
  end
end
