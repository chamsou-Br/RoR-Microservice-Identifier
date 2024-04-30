# frozen_string_literal: true

class ContributionsController < ApplicationController
  before_action :context

  def create
    @contribution = @context.contributions.build(contribution_params)
    authorize @context, :create_contribution?
    @context.errors.add :base, "can't add contribution" unless @contribution.save
  end

  def update
    @contribution = @context.contributions.find(params[:id])
    authorize @contribution, :edit_contribution?
    @contribution.content = params[:content]
    respond_to do |format|
      format.json do
        render json: @contribution if @contribution.save
      end
    end
  end

  def destroy
    @contribution_id = params[:id]
    @contribution = @context.contributions.find(params[:id])
    @contribution.destroy
  end

  private

  def contribution_params
    params.require(:contribution).permit(:content, :user_id)
  end

  # TODO: Refactor to use param key hash like `#{type}_id`
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def context
    if params[:graph_id]
      @context = current_customer.graphs.find_by(id: params[:graph_id])
      @wf_entity_type = "graph"
    elsif params[:event_id]
      @context = current_customer.events.find_by(id: params[:event_id])
      @wf_entity_type = "event"
    elsif params[:act_id]
      @context = current_customer.acts.find_by(id: params[:act_id])
      @wf_entity_type = "act"
    elsif params[:audit_id]
      @context = current_customer.audits.find_by(id: params[:audit_id])
      @wf_entity_type = "audit"
    elsif !params[:document_id].nil?
      @context = current_customer.documents.find_by(id: params[:document_id])
      @wf_entity_type = "document"
    end

    return unless @context.nil?

    case @wf_entity_type
    when "graph"
      flash_x_error I18n.t("controllers.actors.errors.find_graph"), :not_found
    when "document"
      flash_x_error I18n.t("controllers.actors.errors.find_document"), :not_found
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def user_not_authorized(exception)
    flash_x_error(
      I18n.t("controllers.contributions.errors.#{exception.policy.class.name.downcase}"),
      :method_not_allowed
    )
  end
end
