# frozen_string_literal: true

class RolesController < ApplicationController
  include TagsHelper
  include RolesHelper
  include Listable
  include UserAssignable

  def index
    respond_to do |format|
      format.html {}
      format.json do
        render_list "index", :list_index_definition, properties: true,
                                                     tags: true,
                                                     favor: true
      end

      format.csv do
        authorize Role, :export?
        roles = current_user.customer.roles
        send_data roles.to_csv, filename: "#{export_file_name}.csv"
      end
      format.xls do
        authorize Role, :export?
        @roles = current_user.customer.roles
        filename = "#{export_file_name}.xls"
        headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
      end
    end
  end

  def new
    @role = Role.new
  end

  # rubocop:disable Metrics/AbcSize
  def create
    @role = current_customer.roles.new(role_params) do |role|
      role.author = current_user
    end
    if @role.save
      flash[:success] = I18n.t("controllers.roles.successes.create")
      respond_to do |format|
        format.html
        format.js
        format.json { render json: @role }
      end
    else
      respond_to do |format|
        format.html { render :new }
        format.js { render :new }
        format.json do
          render json: { full_errors: @role.errors.full_messages,
                         errors: @role.errors.messages }, status: 422
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def show_properties
    @role = current_user.customer.roles.find(params[:id])
    authorize @role, :show?

    @users = @role.users

    roles_ids = []
    roles_ids << @role.id

    @graphs = scoped_graphs(roles_ids)
  end

  def show
    build_role_and_properties
    authorize @role, :show?

    respond_to do |format|
      format.json { render json: { properties: @role.to_json(include: %i[tags author]) } }
      format.html do
        redirect_to show_properties_role_path(@role)
      end
    end
  end

  def edit
    @role = current_user.customer.roles.find(params[:id])
    @role.author_id ||= current_user.id
  end

  # rubocop:disable Metrics/AbcSize
  def update
    @role = Role.find(params[:id])
    params[:role][:tags] = consolidate(params[:role][:tags]) if params[:role][:tags]

    respond_to do |format|
      if @role.update_attributes(role_params)
        format.html do
          flash[:success] = I18n.t("controllers.roles.successes.update")
          redirect_to :edit_role
        end
      else
        format.html do
          flash.now[:error] = I18n.t("controllers.roles.errors.update")
          logger.debug "--> @role.errors.messages : #{@role.errors.messages}"
          render action: "edit"
        end
      end

      format.json { respond_with_bip(@role) }
    end
  end
  # rubocop:enable Metrics/AbcSize

  def update_tags
    tags = JSON.parse params[:tags]
    @role = current_user.customer.roles.find(params[:id])

    authorize @role, :update_tags?
    records = []
    tags.each do |tag|
      tag_rec = current_customer.tags.find_or_create_by(label: tag["text"])
      records << tag_rec
    end
    @role.update_attributes(tags: records)
    @role.save
    @tags = @role.tags

    render "tags/update_tags"
  end

  def linkable
    # return if !request.xhr?
    element_type = params[:type]
    roles = current_customer.roles.active.where(type: element_type).order(:title)
    respond_to do |format|
      format.json { render json: { roles: roles.to_json } }
    end
  end

  def delete_one
    @role = current_customer.roles.find(params[:id])
    errors = []
    Role.transaction do
      unless @role.destroy
        errors << @role.title
        raise ActiveRecord::Rollback
      end
    end
    if errors.none?
      flash_x_success I18n.t("controllers.roles.successes.delete_one")
      redirect_to roles_path
    else
      flash_x_error I18n.t("controllers.roles.errors.delete", role: @role.title)
      redirect_to show_properties_role_path(@role)
    end
  end

  def delete
    authorize Role, :destroy?
    roles = list_selection(:list_index_definition) || []
    count = roles.count
    errors = []
    Role.transaction do
      roles.each do |role|
        errors << role.title unless role.destroy
      end
      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.none?
      flash[:success] = I18n.t("controllers.roles.successes.delete", count: count)
      # respond_to { |f| f.js {} }
    else
      flash[:error] = humanize_delete_error(errors)
    end
  rescue Pundit::NotAuthorizedError
    flash_x_error "Not authorized", :method_not_allowed
  end

  def print
    build_role_and_properties

    respond_to do |format|
      format.pdf do
        header = render_to_string(layout: nil, action: "print_header.html.erb", locals: { role: @role })

        html = render_to_string(layout: nil, action: "print.html.erb", locals: { role: @role })
        footer = render_to_string(layout: nil,
                                  action: "../print/footer.html.erb",
                                  locals: { content: current_customer.settings.print_footer })

        send_data pdf_from_string(html, header: header, footer: footer),
                  disposition: "inline",
                  filename: "print.pdf",
                  type: "application/pdf"
        return
      end
    end
  end

  def confirm_deactivate_one
    @role = current_customer.roles.find(params[:id])
  end

  # Reactivate a role from its properties page.
  # POST request
  def reactivate_one
    reactivate_role
    redirect_to show_properties_role_path(@role)
  end

  # Reactivate roles from list.
  # GET request
  def reactivate
    reactivate_role
  end

  def deactivate_one
    @role = current_customer.roles.find(params[:id])
    errors = []

    Role.transaction do
      unless @role.update_attributes(deactivated: true)
        errors << @role.title
        raise ActiveRecord::Rollback
      end
    end

    if errors.any?
      flash_x_error I18n.t("controllers.roles.errors.deactivate", role: @role.title)
    else
      flash_x_success I18n.t("controllers.roles.successes.deactivate_one")
    end

    redirect_to show_properties_role_path(@role)
  end

  def confirm_deactivate
    roles = list_selection(:list_index_definition) || []
    @roles_in_graph_applicable = roles.select(&:has_any_graphs_in_application?)
  end

  def deactivate
    roles = list_selection(:list_index_definition) || []
    errors = []

    Role.transaction do
      roles.each do |role|
        errors << role.title unless role.update_attributes(deactivated: true)
      end
      raise ActiveRecord::Rollback if errors.any?
    end

    if errors.any?
      flash_x_error I18n.t("controllers.roles.errors.deactivate", role: @role.title)
    else
      flash_x_success I18n.t("controllers.roles.successes.deactivate_one")
    end
  rescue Pundit::NotAuthorizedError
    flash_x_error "Not authorized", :method_not_allowed
  end

  def interactions
    @role = current_customer.roles.find params[:id]
    authorize @role, :view_interactions?

    @users = @role.users

    roles_ids = []
    roles_ids << @role.id

    with_archived = true
    @graphs = current_user.related_role_graphs(roles_ids, with_archived)
  end

  private

  #
  # File name for the generated role export
  #
  # @return [String] File name without extension
  #
  def export_file_name
    "#{current_customer.nickname}_" \
      "#{t('roles.xls.filename')}_#{I18n.l(Time.current, format: :file_export)}"
  end

  #
  # Returns a `WickedPdf` with the provided string of content
  #
  # @param [String] html
  # @param [String] header
  # @param [String] footer
  #
  # @return [WickedPdf]
  #
  def pdf_from_string(html, header:, footer:)
    WickedPdf.new.pdf_from_string(html, header: { content: header },
                                        footer: { content: footer },
                                        margin: { top: 30,
                                                  bottom: 10,
                                                  left: 1,
                                                  right: 1 })
  end

  def role_params
    params.require(:role).permit(:title, :type, :activities, :mission, :purpose)
  end

  def build_role_and_properties
    @role = current_user.customer.roles.includes(:tags).find(params[:id])
    @users = @role.users

    roles_ids = []
    roles_ids << @role.id

    @graphs = scoped_graphs(roles_ids)
  end

  def list_index_definition
    {
      items: lambda {
        policy_scope(Role)
      },
      search: lambda { |_roles, term|
        Role.search_list(term, current_user).records
      },
      tabs: (current_user.process_power_user? ? power_user_tabs : simple_user_tabs),
      orders: {
        title: ->(roles) { roles.order("title") },
        title_inv: ->(roles) { roles.order("title DESC") },
        type: ->(roles) { roles.order("type, title") },
        updated: ->(roles) { roles.order("updated_at DESC, title") }
      }
    }
  end

  def power_user_tabs
    {
      myroles: ->(roles) { roles.where(id: current_user.roles, deactivated: false) },
      favored: ->(resources) { resources.where(id: current_user.roles_favored, deactivated: false) },
      active: ->(roles) { roles.where(id: current_customer.active_roles) },
      deactivated: ->(roles) { roles.where(id: current_customer.deactivated_roles) },
      all: ->(roles) { roles }
    }
  end

  def simple_user_tabs
    {
      myroles: ->(roles) { roles.where(id: current_user.roles, deactivated: false) },
      favored: ->(resources) { resources.where(id: current_user.roles_favored, deactivated: false) },
      active: ->(roles) { roles.where(id: current_customer.active_roles) },
      all: ->(roles) { roles.where(id: current_customer.active_roles) }
    }
  end

  def reactivate_role
    @role = current_customer.roles.find(params[:id])
    authorize @role, :reactivate?

    if @role.update_attributes(deactivated: false)
      flash_x_success I18n.t("controllers.roles.successes.reactivate")
    else
      flash_x_error I18n.t("controllers.roles.errors.reactivate")
    end
  end

  def scoped_graphs(roles_ids)
    if current_user.process_power_user?
      current_customer.graphs.related_role_graphs_to_admin_or_designer(roles_ids)
    else
      current_customer.graphs.related_role_graphs(roles_ids)
    end
  end
end
