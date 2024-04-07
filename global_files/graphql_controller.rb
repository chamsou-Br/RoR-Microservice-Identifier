# frozen_string_literal: true

class GraphqlController < ApplicationController
  def execute
    context = {
      # Query context goes here, for example:
      current_user: current_user,
      current_customer: current_customer
    }

    result = if params[:_json]
               execute_multi(context)
             else
               execute_single(context)
             end

    render json: result
  end

  private

  def execute_single(context)
    variables = ensure_hash(params[:variables])
    query = params[:query]
    operation_name = params[:operationName]
    QualipsoSchema.execute(query,
                           variables: variables,
                           operation_name: operation_name,
                           context: context)
  end

  def execute_multi(context)
    queries = params[:_json].map do |param|
      {
        query: param[:query],
        variables: ensure_hash(param[:variables]),
        operation_name: param[:operationName],
        context: context
      }
    end
    QualipsoSchema.multiplex(queries)
  end

  # Handle form data, JSON body, or a blank value
  def ensure_hash(ambiguous_param)
    case ambiguous_param
    when String
      if ambiguous_param.present?
        ensure_hash(JSON.parse(ambiguous_param))
      else
        {}
      end
    when Hash, ActionController::Parameters
      ambiguous_param
    when nil
      {}
    else
      raise ArgumentError, "Unexpected parameter: #{ambiguous_param}"
    end
  end
end
