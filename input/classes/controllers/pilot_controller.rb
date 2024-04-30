# frozen_string_literal: true

class PilotController < ApplicationController
  before_action :context
  after_action :verify_authorized

  def new
    open_form_pilot
  end

  def edit
    open_form_pilot
  end

  def create
    set_pilot
  end

  def update
    set_pilot
  end

  private

  def context
    return unless params[:document_id]

    @context = current_customer.documents.find_by(id: params[:document_id])
    authorize @context, :change_pilot?
    @wf_entity_type = "document"
  end

  def user_not_authorized(exception)
    flash_x_error I18n.t("controllers.contributions.errors.#{exception.policy.class.name.downcase}"),
                  :method_not_allowed
  end

  def open_form_pilot
    respond_to do |format|
      format.js { render :open_form_pilot }
      format.html {}
    end
  end

  def set_pilot
    if !@context.nil? && @context.change_pilot(current_user, params[:document][:pilot_id])
      flash[:success] = I18n.t("controllers.documents.successes.pilot_changed")
    else
      flash[:error] = I18n.t("controllers.documents.errors.change_pilot")
    end

    respond_to do |format|
      format.js { render js: "Turbolinks.visit('#{show_properties_document_path(@context)}')" }
    end
  end
end
