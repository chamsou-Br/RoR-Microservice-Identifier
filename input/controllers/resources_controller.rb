# frozen_string_literal: true

class ResourcesController < ApplicationController
  include Listable
  include ResourcesHelper

  skip_before_action :authenticate_user!, only: [:serve_logo]

  # TODO: Refactor renderers into separate private methods
  # rubocop:disable Metrics/AbcSize
  def index
    respond_to do |format|
      format.html {}
      format.json do
        render_list "index", :list_index_definition, properties: true, tags: true, favor: true
      end

      format.csv do
        authorize Resource, :export?
        resources = current_user.customer.resources
        send_data resources.to_csv, filename: "#{current_customer.nickname}_#{t('resources.xls.filename')}_" \
                                              "#{I18n.l(Time.current, format: :file_export)}.csv"
      end

      format.xls do
        authorize Resource, :export?
        @resources = current_user.customer.resources
        filename = "#{current_customer.nickname}_#{t('resources.xls.filename')}_" \
                   "#{I18n.l(Time.current, format: :file_export)}.xls"
        headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def show
    @resource = current_customer.resources.find(params[:id])
    authorize @resource, :show?

    respond_to do |format|
      format.json { render json: { properties: @resource.to_json } }
      format.html { redirect_to show_properties_resource_path(@resource) }
    end
  end

  def absolute_url
    @resource = current_customer.resources.find(params[:id])
    authorize @resource, :show?

    if @resource.absolute_url.present?
      redirect_to @resource.absolute_url
    else
      redirect_to show_properties_resource_path(@resource)
    end
  end

  def show_properties
    @resource = current_user.customer.resources.find(params[:id])
    authorize @resource, :show?
  end

  def interactions
    @resource = current_user.customer.resources.find(params[:id])
    @linked_graphs = @resource.linked_graphs
  end

  def new
    @resource = Resource.new
    respond_to do |format|
      format.js {}
      format.json do
        @submit_format = "json"
        form_new_html = render_to_string(partial: "form_new", formats: [:html])
        render json: { form_new: form_new_html }
      end
    end
  end

  # TODO: Simplify into smaller private methods
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def create
    @resource = current_customer.resources.new(resource_params) do |resource|
      resource.author = current_user
    end

    begin
      authorize @resource, :action_resource?
    rescue StandardError
      @resource.errors.add :base, I18n.t("resources.failure.create.policy")
    end

    if @resource.errors.empty? && @resource.save
      flash_x_success I18n.t("resources.success.create")
      respond_to do |format|
        format.js {}
        format.json { render json: @resource }
      end
    elsif params[:renaissance]
      respond_to do |format|
        format.json do
          render json: { full_errors: @resource.errors.full_messages, errors: @resource.errors.messages }, status: 422
        end
      end
    else
      # we have the same behavior on errors in json/js request format
      if request.format == :json
        request.format = :js
        @submit_format = "json"
      end
      respond_to { |format| format.js { render :new } }
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def delete
    authorize Resource, :action_resource?
    resources = list_selection(:list_index_definition) || []
    errors = []
    Resource.transaction do
      resources.each do |resource|
        errors << resource.title unless resource.destroy
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.blank?
      flash[:success] = I18n.t("resources.success.delete", count: resources.count)
    else
      flash[:error] = humanize_delete_error(errors)
    end
    # respond_to_js :reload
  rescue Pundit::NotAuthorizedError
    flash_x_error "Not authorized", :method_not_allowed
  end

  def delete_one
    @resource = current_customer.resources.find(params[:id])
    begin
      authorize @resource, :action_resource?
    rescue StandardError
      @resource.errors.add :base, I18n.t("resources.failure.delete_one.policy")
    end
    if @resource.errors.empty? && @resource.destroy
      flash[:success] = I18n.t("resources.success.delete_one")
      redirect_to resources_path
    else
      flash[:error] = I18n.t("resources.failure.delete_one.common_message")
      redirect_to resource_path(@resource)
    end
  end

  def update
    @resource = current_user.customer.resources.find(params[:id])
    authorize @resource, :action_resource?
    @resource.update_attributes(resource_params)
    respond_with_bip(@resource)
  end

  def update_tags
    tags = JSON.parse params[:tags]
    @resource = current_user.customer.resources.find(params[:id])

    authorize @resource, :update_tags?
    records = []
    tags.each do |tag|
      tag_rec = current_customer.tags.find_or_create_by(label: tag["text"])
      records << tag_rec
    end
    @resource.tags = records
    @resource.save
    @tags = @resource.tags

    render "tags/update_tags"
  end

  def update_url
    @resource = current_user.customer.resources.find(params[:id])
    @resource.url = nil
    if @resource.update_attributes(resource_params)
      flash[:success] = I18n.t("resources.success.update_url")
    else
      flash[:error] = I18n.t("resources.failure.update_url")
    end
    respond_to_js
  end

  def edit_url
    @resource = current_customer.resources.find(params[:id])
  end

  def linkable
    return unless request.xhr?

    resources = current_customer.resources.active
    respond_to do |format|
      format.json { render json: { resources: resources.to_json } }
    end
  end

  # begin logo actions
  def update_logo
    @resource = current_customer.resources.find(params[:id])
    authorize @resource, :update_logo?

    if @resource.update_attributes(resource_params)
      flash_x_success t("controllers.users.successes.update_avatar")
    else
      flash_x_error t("controllers.users.error.update_avatar")
    end
    respond_to do |format|
      format.js {}
    end
  end

  def serve_logo
    return head :not_found if current_customer.nil?

    @resource = current_customer.resources.find(params[:id])
    version = params[:version] || "standard"

    path = "public"

    begin
      case version
      when "standard" then path += @resource.logo_url.to_s
      when "show" then path += @resource.logo_url(:show).to_s
      when "preview" then path += @resource.logo_url(:preview).to_s
      end

      send_file(path, disposition: "inline", x_sendfile: true)
    rescue ActionController::MissingFile
      head :not_found
    end
  end

  def crop_logo
    @resource = current_customer.resources.find(params[:id])
    authorize @resource, :update_logo?
  end

  def confirm_delete_logo
    @resource = current_customer.resources.find(params[:id])

    respond_to do |format|
      format.js {}
    end
  end

  def delete_logo
    @resource = current_customer.resources.find(params[:id])
    authorize @resource, :delete_logo?

    # if @resource.logo.remove!
    if @resource.remove_logo! && @resource.save
      @resource.update_linked_elements
      flash[:success] = I18n.t("controllers.settings.delete_logo.success")
    else
      flash[:error] = I18n.t("controllers.settings.delete_logo.error")
    end
    redirect_to resource_path(@resource)
  end

  def update_crop_logo
    @resource = current_customer.resources.find(params[:id])
    authorize @resource, :delete_logo?

    @resource.crop_logo(params[:crop_x], params[:crop_y], params[:crop_w], params[:crop_h])
    redirect_to resource_path(@resource)
  end
  # end logo actions

  # begin deactivation actions
  def confirm_deactivate_one
    @resource = current_customer.resources.find(params[:id])
    authorize @resource, :deactivate?
  end

  def deactivate_one
    @resource = current_customer.resources.find(params[:id])
    authorize @resource, :deactivate?

    if @resource.update(deactivated: true)
      flash_x_success I18n.t("resources.success.deactivate_one")
    else
      flash_x_error I18n.t("resources.failure.deactivate_one")
    end

    redirect_to resource_path(@resource)
  end

  def confirm_deactivate
    resources = list_selection(:list_index_definition) || []
    @resources_in_graph_applicable = resources.select(&:has_any_graphs_in_application?)
  end

  def deactivate
    resources = list_selection(:list_index_definition) || []
    errors = []

    Resource.transaction do
      resources.each do |resource|
        errors << resource.title unless resource.update_attributes(deactivated: true)
      end

      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.any?
      flash_x_error I18n.t("resources.failure.deactivate", resource: @resource.title)
    else
      flash_x_success I18n.t("resources.success.deactivate_one")
    end
  rescue Pundit::NotAuthorizedError
    flash_x_error "Not authorized", :method_not_allowed
  end

  # Reactivate roles from list.
  # GET request
  def reactivate
    reactivate_resource
  end

  private

  def resource_params
    params.require(:resource).permit(:logo, :logo_cache, :original_logo_filename,
                                     :title, :resource_type, :url, :purpose)
  end

  def respond_to_js(template = nil)
    respond_to do |f|
      template.nil? ? f.js {} : f.js { render template }
    end
  end

  def list_index_definition
    {
      items: -> { current_user.accessible_resources.includes(:tags, :likers) },
      search: ->(_resources, term) { Resource.search_list(term, current_user).records },
      tabs: (current_user.process_power_user? ? power_user_tabs : simple_user_tabs),
      orders: {
        title: ->(resources) { resources.order("title") },
        title_inv: ->(resources) { resources.order("title DESC") },
        type: ->(resources) { resources.order("resource_type, title") },
        updated: ->(resources) { resources.order("updated_at DESC, title") }
      }
    }
  end

  def power_user_tabs
    {
      favored: ->(resources) { resources.active.where(id: current_user.resources_favored) },
      active: ->(resources) { resources.where(id: current_customer.resources.active) },
      deactivated: ->(resources) { resources.where(id: current_customer.resources.inactive) },
      all: ->(resources) { resources }
    }
  end

  def simple_user_tabs
    {
      favored: ->(resources) { resources.active.where(id: current_user.resources_favored) },
      active: ->(resources) { resources.where(id: current_customer.resources.active) },
      all: ->(resources) { resources }
    }
  end

  def reactivate_resource
    @resource = current_user.customer.resources.find(params[:id])
    authorize @resource, :reactivate?

    if @resource.update_attributes(deactivated: false)
      flash_x_success I18n.t("resources.success.reactivate")
    else
      flash_x_error I18n.t("resources.failure.reactivate")
    end

    respond_to do |format|
      format.js {}
      format.html { redirect_to resource_path(@resource) }
    end
  end
end
