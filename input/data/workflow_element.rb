# frozen_string_literal: true

class WorkflowElement
  extend ActiveModel::Naming
  include ActiveModel::Model

  attr_accessor :type, :object, :title, :function, :viewer, :verifier,
                :approver, :publisher

  def initialize(attributes = {})
    @viewer = @verifier = @approver = @publisher = false
    super attributes
  end
end
