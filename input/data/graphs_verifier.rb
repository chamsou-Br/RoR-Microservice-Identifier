# frozen_string_literal: true

# == Schema Information
#
# Table name: graphs_verifiers
#
#  id          :integer          not null, primary key
#  graph_id    :integer
#  verifier_id :integer
#  verified    :boolean          default(FALSE), not null
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  comment     :string(765)
#  historized  :boolean          default(FALSE), not null
#
# Indexes
#
#  index_graphs_verifiers_on_graph_id                  (graph_id)
#  index_graphs_verifiers_on_graph_id_and_verifier_id  (graph_id,verifier_id)
#  index_graphs_verifiers_on_verifier_id               (verifier_id)
#

class GraphsVerifier < ApplicationRecord
  # #Elasticsearch
  include SearchableGraphsVerifier

  # @!attribute [rw] verifier
  #   @return [User]
  belongs_to :verifier, class_name: "User"

  # @!attribute [rw] graph
  #   @return [Graph]
  belongs_to :graph

  scope :current, -> { where(historized: false) }
  scope :pending, -> { where(historized: false, verified: false) }

  before_save :check_comment

  def self.duplicate_for(graph_duplicated, graph_template = nil)
    graph_template = graph_duplicated.parent if graph_template.nil?
    graph_template.graphs_verifiers.current.each do |graph_verifier|
      graph_verifier_duplicated = graph_verifier.dup
      graph_verifier_duplicated.graph = graph_duplicated
      graph_verifier_duplicated.verified = false
      graph_verifier_duplicated.comment = nil
      graph_verifier_duplicated.save
    end
  end

  #
  # Full name of the verifier
  #
  # @return [String]
  # @deprecated Use the {#verifier} directly and get its full name using
  #   {User#name} and {User::Name#full}.
  #
  def display_verifier_username
    verifier.name.full
  end

  def check_comment
    return unless !comment.nil? && comment.length > graph.comment_wf_max_length

    self.comment = comment[0..(graph.comment_wf_max_length - 1)]
  end
end
