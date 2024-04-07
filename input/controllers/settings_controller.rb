# frozen_string_literal: true

class SettingsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:serve_logo]
  before_action :load_and_authorize_settings_update, only: %i[
    update_nickname update_referent_contact update_password_policy
    update_user_deactivation update_deactivation_period update
    change_approved_read
  ]

  def update
    if @settings.update(settings_params)
      flash[:success] = I18n.t("controllers.settings.pastilles.successes")
      redirect_to edit_settings_path
    else
      flash[:error] = I18n.t("controllers.settings.pastilles.errors")
      render :edit
    end
  end

  def update_authentication_strategy
    @settings = current_customer.settings

    authorize @settings

    if @settings.update(authentication_strategy_params)
      flash[:success] = I18n.t("controllers.settings.authentication_strategy.successes")
    else
      flash[:error] = @settings.errors[:authentication_strategy].join("<br>")
    end
    redirect_to request.referer || general_settings_path
  end

  def edit
    @settings = current_customer.settings
    authorize @settings
  end

  # Import Users Tab
  def user_import
    @settings = current_customer.settings
    authorize @settings, :import_user?
  end

  def show_localisation_preference
    @settings = current_customer.settings
    authorize @settings, :show_localisation_preference?

    response = { localisation_preference: @settings.localisation_preference }

    respond_to do |format|
      format.json { render json: response.as_json }
    end
  end

  def user_csv_template
    respond_to do |format|
      format.csv do
        empty_csv = User.generate_csv_template
        send_data(empty_csv, type: "application/csv", disposition: "attachment", filename: "user_import_template.csv")
      end
    end
  end

  # TODO: Simplify by using private methods in the controller or on the models
  # themselves
  # rubocop:disable Metrics/AbcSize
  def handle_user_import
    @settings = current_customer.settings
    authorize @settings, :import_user?

    @attachment = params[:user_import][:attachment]
    # handle upload wtih carrierwave
    uploader = UsersListUploader.new
    uploader.cache!(@attachment)
    import = User.import_form_csv(uploader.file, current_customer) unless @attachment.nil?

    @errors = import[:errors]

    if @errors.map { |_k, v| v unless v.blank? }.compact.blank? && !@attachment.nil?
      @users = import[:users]
      flash_x_success I18n.t("controllers.settings.handle_user_import.success")
    else
      flash_x_error I18n.t("controllers.settings.handle_user_import.error")
      render :error_user_import
    end
  end
  # rubocop:enable Metrics/AbcSize

  # # General Tab # #
  def general
    @settings = current_customer.settings
    @root_graph = current_customer.root_graph
    @owner = current_customer.owner
    authorize @settings, :edit_general_info?
  end

  def customer_img
    @settings = current_customer.settings
    # authorize @settings, :customer_images?
  end

  def update_logo
    @settings = current_customer.settings
    authorize @settings, :update_logo?

    if @settings.update_attributes(settings_params)
      flash_x_success t("controllers.users.successes.update_avatar")
    else
      flash_x_error t("controllers.users.error.update_avatar")
    end
    respond_to do |format|
      format.js {}
    end
  end

  def update_nickname
    @settings.update_attributes!(settings_general)
    field = @settings[:nickname]
    if field.blank?
      @settings.update_attributes!(nickname: current_customer.subdomain)
      flash_x_warn t(".blank", value: current_customer.subdomain)
      render json: { saved: current_customer.subdomain }
    else
      flash_x_success t(".success")
      render json: { saved: field }
    end
  rescue StandardError
    message = build_validation_error_or_failure(:nickname)
    flash_x_error message
    render status: 422, json: { error: message }
  end

  def update_referent_contact
    @settings.update_attributes!(settings_general)
    field = @settings[:referent_contact]
    if field.blank?
      flash_x_success t(".blank")
    else
      flash_x_success t(".success", email: field)
    end
    render json: { saved: field }
  rescue StandardError
    message = build_validation_error_or_failure(:referent_contact)
    flash_x_error message
    render status: 422, json: { error: message }
  end

  def serve_logo
    @settings = current_customer.settings
    version = params[:version] || "standard"

    path = case version
           when "standard" then @settings.logo.path
           when "show" then @settings.logo.show.path
           when "preview" then @settings.logo.preview.path
           when "print" then @settings.logo.print.path
           else
             @settings.logo.path
           end

    send_file(path,
              disposition: "inline",
              x_sendfile: true)
  end

  def crop_logo
    @settings = current_customer.settings
    authorize @settings, :update_logo?
  end

  def update_crop_logo
    @settings = current_customer.settings
    authorize @settings, :update_logo?
    @settings.crop_logo(params[:crop_x], params[:crop_y], params[:crop_w], params[:crop_h])
    redirect_to general_settings_path
  end

  def confirm_delete_logo
    @settings = current_customer.settings
    authorize @settings, :delete_logo?

    respond_to do |format|
      format.js {}
    end
  end

  def delete_logo
    @settings = current_customer.settings
    authorize @settings, :delete_logo?
    if @settings.logo.remove!
      flash[:success] = I18n.t("controllers.settings.delete_logo.success")
    else
      flash[:error] = I18n.t("controllers.settings.delete_logo.error")
    end
    redirect_to general_settings_path
  end

  def change_time_zone
    @settings = current_customer.settings
    authorize @settings, :change_time_zone?

    if @settings.update_attributes(settings_time_zone_params)
      flash_x_success I18n.t("controllers.settings.time_zone.successes")
    else
      flash_x_error I18n.t("controllers.settings.time_zone.errors")
    end

    head :ok
  end

  def change_logo_usage
    @settings = current_customer.settings
    authorize @settings, :change_logo_usage?

    if @settings.update_attributes(settings_logo_usage_params)
      flash_x_success I18n.t("controllers.settings.logo_usage.successes")
    else
      flash_x_error I18n.t("controllers.settings.logo_usage.errors")
    end

    head :ok
  end

  def edit_print_footer
    @settings = current_customer.settings
    authorize @settings, :edit_print_footer?

    if @settings.update_attributes(settings_print_footer_params)
      flash_x_success I18n.t("controllers.settings.print_footer.successes")
    else
      flash_x_error I18n.t("controllers.settings.print_footer.errors")
    end

    head :ok
  end

  def change_approved_read
    if @settings.update_attributes(settings_approved_read_params)
      flash_x_success I18n.t("controllers.settings.approved_read.success")
    else
      flash_x_error I18n.t("controllers.settings.approved_read.error")
    end

    head :ok
  end

  def update_owner_users_management
    @settings = current_customer.settings
    authorize @settings

    if @settings.update_attributes(settings_params)
      flash_x_success I18n.t("controllers.settings.owner_users_management.success")
    else
      flash_x_error I18n.t("controllers.settings.owner_users_management.error")
    end

    head :ok
  rescue StandardError
    flash_x_error I18n.t("errors.operation_failed"), :method_not_allowed
  end

  def update_password_policy
    if @settings.update_attributes(settings_pwd_policy_params)
      flash_x_success I18n.t("controllers.settings.password_policy.success")
    else
      flash_x_error I18n.t("controllers.settings.password_policy.error")
    end
    head :ok
  end

  def update_user_deactivation
    if @settings.update_attributes(user_deactivation_params)
      flash_x_success I18n.t("controllers.settings.user_deactivation.success")
    else
      flash_x_error @settings.errors.full_messages.join(", ")
    end
    head :ok
  end

  def update_deactivation_period
    if @settings.update_attributes(deactivation_period_params)
      flash_x_success I18n.t("controllers.settings.user_deactivation.success")
      render json: { saved: @settings.deactivation_wait_period_days }
    else
      message = build_validation_error_or_failure(:deactivation_wait_period_days)
      flash_x_error message
      render status: 422, json: { error: message }
    end
  end

  # # End General Tab # #

  # # Colors Tab # #
  def update_colors
    @settings = current_customer.settings
    authorize @settings, :update_colors?

    begin
      @settings.colors.custom.destroy_all
      @successful = true
      JSON.parse(params[:colors]).each do |color|
        color_record = @settings.colors.create(color)
        @successful = false if color_record.errors.any?
      end
      if @successful
        flash_x_success I18n.t("controllers.settings.colors.update_colors.success")
        @colors = @settings.colors.custom
      end
    rescue StandardError
      flash_x_error I18n.t("controllers.settings.colors.update_colors.error")
    end
    respond_to do |format|
      format.js {}
    end
  end

  # TODO: Simplify by using private methods in the controller or on the models
  # themselves
  # rubocop:disable Metrics/AbcSize
  def toggle_color
    @settings = current_customer.settings
    authorize @settings, :toggle_color?

    # default attribute doesn't seem to work in the find_by clause
    colors_scope = if settings_palette_color_params[:default] == "true"
                     @settings.colors.default
                   else
                     @settings.colors.custom
                   end

    @color = colors_scope.find_by(value: settings_palette_color_params[:value],
                                  position: settings_palette_color_params[:position])
    if !@color.nil? && @color.update_attributes(settings_palette_color_params)
      flash_x_success I18n.t("controllers.settings.colors.toggle_color.success")
    else
      flash_x_error I18n.t("controllers.settings.colors.toggle_color.error")
    end

    respond_to do |format|
      format.js {}
    end
  end
  # rubocop:enable Metrics/AbcSize

  # TODO: Simplify by using private methods in the controller or on the models
  # themselves
  # rubocop:disable Metrics/AbcSize
  def delete_color
    @settings = current_customer.settings
    authorize @settings, :delete_color?

    color = @settings.colors.find_by(value: params[:color][:value], position: params[:color][:position])
    if !color.nil? && @settings.colors.destroy(color)
      flash_x_success I18n.t("controllers.settings.colors.delete_color.success")
      @colors = @settings.colors.custom
    else
      flash_x_error I18n.t("controllers.settings.colors.delete_color.error")
    end

    @colors = @settings.colors.custom

    respond_to do |format|
      format.js {}
    end
  end
  # rubocop:enable Metrics/AbcSize

  def colors
    @settings = current_customer.settings
    colors = {}
    @settings.colors.active.all.each do |color_record|
      colors[color_record.value.to_s] = []
      @settings.colors.shades_palette(color_record.value).each do |palette|
        colors[color_record.value.to_s] << palette.hex
      end
    end
    respond_to do |format|
      format.json { render json: { colors: colors }.to_json }
    end
  end
  # # End Colors Tab # #

  private

  def load_and_authorize_settings_update
    @settings = current_customer.settings
    authorize @settings, :update?
  end

  def build_validation_error_or_failure(field_name)
    if @settings.errors.include?(field_name)
      @settings.errors.full_messages_for(field_name)[0]
    else
      I18n.t("errors.operation_failed")
    end
  end

  def settings_params
    params.require(:customer_setting).permit(
      :logo,
      :logo_cache,
      :original_logo_filename,
      :owner_users_management,
      :localisation_preference,
      pastilles_attributes: %i[id label _destroy color activated desc_en desc_fr desc_es desc_nl desc_de]
    )
  end

  def authentication_strategy_params
    params.require(:customer_setting).permit(:authentication_strategy)
  end

  def settings_time_zone_params
    params.require(:customer_setting).permit(:time_zone)
  end

  def settings_logo_usage_params
    params.require(:customer_setting).permit(:logo_usage)
  end

  def settings_print_footer_params
    params.require(:customer_setting).permit(:print_footer)
  end

  def settings_general
    params.require(:customer_setting).permit(:referent_contact, :nickname)
  end

  def settings_approved_read_params
    params.require(:customer_setting).permit(:approved_read)
  end

  def settings_palette_color_params
    params.require(:color).permit(:value, :active, :default, :position)
  end

  def settings_pwd_policy_params
    params.require(:customer_setting).permit(:password_policy_enabled)
  end

  def user_deactivation_params
    params.require(:customer_setting).permit(:automatic_user_deactivation_enabled)
  end

  def deactivation_period_params
    params.require(:customer_setting).permit(:deactivation_wait_period_days)
  end
end
