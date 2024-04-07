# frozen_string_literal: true

# == Schema Information
#
# Table name: graphs_logs
#
#  id         :integer          not null, primary key
#  graph_id   :integer
#  action     :string(255)
#  comment    :string(765)
#  user_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_graphs_logs_on_graph_id  (graph_id)
#  index_graphs_logs_on_user_id   (user_id)
#

class GraphsLog < ApplicationRecord
  belongs_to :graph
  belongs_to :user

  validates :action, presence: true
  validates :graph, :user, presence: true

  before_save :check_comment

  def check_comment
    return unless !comment.nil? && comment.length > graph.comment_wf_max_length

    self.comment = comment[0..(graph.comment_wf_max_length - 1)]
  end
end
