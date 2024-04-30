# frozen_string_literal: true

class RegistrationsController < Devise::RegistrationsController
  include ListableUser

  def destroy
    # Surcharge du destroy de Devise pour empêcher la suppression accidentelle d'un user.
    logger.debug "--> Destroy du user bloqué !!"
  end

  def edit
    @user = params[:id].nil? ? current_user : current_customer.users.find(params[:id])

    authorize @user, :edit?
  end

  def edit_password
    @user = current_user
  end

  def update_password
    @user = current_customer.users.find(current_user.id)
    authorize @user, :edit_pwd?

    if params[:user][:password].blank?
      @user.errors.add(:password, I18n.t("blank", scope: "activerecord.errors.models.user.attributes.password"))
    end

    if @user.errors.empty? && @user.update_with_password(user_password_params)
      sign_in @user, bypass: true
      flash[:success] = I18n.t("controllers.registrations.successes.update_password")
    else
      render :edit_password
    end
  end

  #
  # Update user properties and rights.
  #
  # @note This method is hard to change because it is used in multiple places:
  # - in Process
  #   - when updating user properties (including profile types) in the user edit page
  #   - when changing profile types in the user list page
  # - in Improver:
  #   - when changing model_lever responsibility, eg. event_manager
  #   - when changing the CIM responsibility
  #
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def update
    @user = params[:id].nil? ? current_user : current_customer.users.find(params[:id])

    if can_change_pyx4_module_responsibilities?
      update_user_profile if params[:user][:profile_type].present?
      update_improver_profile if params[:user][:improver_profile_type].present?
      update_user(user_params) unless @user.errors.any?
    elsif params[:user][:profile_type].nil? && params[:user][:improver_profile_type].nil?
      update_user(user_params_without_rights) unless @user.errors.any?
    else
      # In this case, the user's customer has reached the maximum number of
      # simple users or power users.  Therefore, they are forbidden from adding/
      # promoting more users unless they augment their Pyx4 package
      @status = :forbidden
      add_max_users_errors
    end

    @user.errors.any? ? respond_bip_error(@user, @status) : render(json: @user)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def edit_profile_type
    @user = current_customer.users.find(params[:id])
    respond_to do |format|
      format.js {}
    end
  end

  def transfer_rights
    @user = current_customer.users.find(params[:id])
    current_user.transfer_rights_to(@user)

    flash[:success] = I18n.t("controllers.registrations.successes.transfer_rights") unless current_user.errors.any?

    respond_to do |format|
      format.js {}
    end
  end

  def confirm_deactivation; end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def deactivate
    authorize current_user, :destroy?
    # @type [Array<User>, nil]
    users = list_selection(:list_index_definition)
    if users
      deactivated = []
      flash_current_user = false
      flash_owner = false
      # Try to deactivate only himself
      if (users.count == 1) && (users.first == current_user)
        flash_current_user = true
        flash_x_error I18n.t("devise.registrations.deactivated_current_user")
      # Try to deactivate only the owner
      elsif (users.count == 1) && users.first.owner
        flash_owner = true
        flash_x_error I18n.t("devise.registrations.deactivated_owner")
      elsif users.include?(current_user) && users.include?(current_customer.owner)
        flash_current_user = true
        flash_owner = true
        users_to_deactivate = users - [current_user] - [current_customer.owner]
        deactivated = User.deactivate(users_to_deactivate)
      # Try to deactivate himself among with others
      elsif users.include?(current_user)
        flash_current_user = true
        deactivated = User.deactivate(users - [current_user])
      elsif users.include?(current_customer.owner)
        flash_owner = true
        deactivated = User.deactivate(users - [current_customer.owner])
      else
        deactivated = User.deactivate(users)
      end
      count = deactivated.count
      if count.positive?
        first = deactivated.first.name.full_inv
        message = if count > 1
                    t("devise.registrations.deactivated_multi", user: first, count: count - 1)
                  else
                    t("devise.registrations.deactivated", user: first)
                  end
        if flash_current_user && flash_owner
          message << "(#{I18n.t('devise.registrations.deactivated_current_user_and_owner')})"
        elsif flash_current_user
          message << "(#{I18n.t('devise.registrations.deactivated_current_user')})"
        elsif flash_owner
          message << "(#{I18n.t('devise.registrations.deactivated_owner')})"
        end
        flash_x_success message
      elsif flash_current_user
        flash_x_error I18n.t("devise.registrations.deactivated_current_user").to_s
      elsif flash_owner
        flash_x_error I18n.t("devise.registrations.deactivated_owner").to_s
      else
        flash_x_error I18n.t("devise.registrations.deactivated_no_one"), :not_found
      end
    end
  rescue StandardError
    flash_x_error I18n.t("errors.operation_failed"), :method_not_allowed
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def restore
    # @type [User]
    user = current_customer.users.find(params[:id])
    locales = { name: user.name.full_inv }
    authorize user, :restore?
    if user.deactivation(false)
      NotificationMailer.inform_user(user).deliver
      flash_x_success t("devise.registrations.restore_user", locales)
    else
      flash_x_error t("devise.registrations.restore_user_errors", locales)
    end
  rescue StandardError
    if user.power_user?
      flash_x_error t("helpers.users.errors.paying_customer.max_power_user"), :method_not_allowed
    else
      flash_x_error t("helpers.users.errors.paying_customer.max_simple_user"), :method_not_allowed
    end
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def update_instance_ownership
    user = current_customer.users.find(params[:id])
    authorize user
    @successful = false
    user = current_customer.update_instance_ownership(user)
    if user.errors.none?
      flash_x_success t("controllers.registrations.successes.update_instance_ownership")
      @successful = true
      @owner = user
      NewNotification.create_and_deliver(
        customer: current_customer,
        category: :update_instance_ownership,
        from: current_user,
        to: @owner,
        entity: @owner
      )
    elsif user.errors.key?(:owner)
      flash_x_error user.errors[:owner].first
      @owner = current_customer.owner
    elsif user.errors.key?(:profile_type)
      flash_x_error user.errors[:profile_type].first
      @owner = current_customer.owner
    elsif user.errors.key?(:improver_profile_type)
      flash_x_error user.errors[:improver_profile_type].first
      @owner = current_customer.owner
    else
      flash_x_error t("controllers.registrations.errors.update_instance_ownership")
      @owner = current_customer.owner
    end
    # TODO: Is it the best way to reload the current user?
    @current_user = current_customer.users.find(current_user.id)
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  private

  def user_params
    params.require(:user).permit(
      :firstname, :lastname, :function, :phone, :service, :skip_homepage, :profile_type, :language, :gender,
      :mobile_phone, :supervisor_id, :working_date, :improver_profile_type, :time_zone, :mail_frequency,
      :mail_weekly_day, :mail_locale_hour, :events_manager, :actions_manager, :audits_organizer,
      :continuous_improvement_manager, :default_continuous_improvement_manager
    )
  end

  def user_params_without_rights
    params.require(:user).permit(
      :firstname, :lastname, :function, :phone, :service, :skip_homepage, :language, :gender,
      :mobile_phone, :supervisor_id, :working_date, :time_zone, :events_manager, :actions_manager,
      :audits_organizer, :continuous_improvement_manager, :default_continuous_improvement_manager
    )
  end

  def list_items_crud(_term = "", _klass = "")
    current_customer.users_list(true, true)
  end

  def list_tabs_crud(_klass = "")
    {
      active: ->(users) { users.where(deactivated: false) },
      power: ->(users) { users.where(profile_type: %w[admin designer]) },
      simple: ->(users) { users.where(profile_type: "user") },
      deactive: ->(users) { users.where(deactivated: true) },
      all: ->(users) { users }
    }
  end

  def user_password_params
    params.require(:user).permit(:password, :password_confirmation, :current_password)
  end

  def respond_bip_error(obj, status = nil)
    code = status.nil? ? :unprocessable_entity : status
    render json: obj.errors, status: code
  end

  #
  # Returns true if the given responsibilities in `params` can be assigned to `@user`
  # without exceeding user limits of the customer.
  #
  # @return [Boolean]
  #
  def can_change_pyx4_module_responsibilities?
    current_customer.can_assign_user?(
      @user,
      process_responsibility: params[:user][:profile_type],
      improver_responsibility: params[:user][:improver_profile_type]
    )
  end

  def update_user_profile
    authorize @user, :update_profile?
    @user.update_without_password(user_params)
  rescue Pundit::NotAuthorizedError
    @user.errors.add :profile_type, :not_authorized
    @status = :forbidden
  end

  def update_improver_profile
    authorize @user, :update_improver_profile?
    @user.update_improver_profile(user_params)
  rescue Pundit::NotAuthorizedError
    @user.errors.add :improver_profile_type, :not_authorized
    @status = :forbidden
  end

  def improver_responsibilities_in_params?
    keys = %w[events_manager actions_manager continuous_improvement_manager audits_organizer]
    (params[:user].keys & keys).any?
  end

  def update_user(params)
    if improver_responsibilities_in_params?
      authorize(@user, :update_improver_responsibilities?)
    else
      authorize(@user, :change_profile_info?)
    end
    @user.update_without_password(params)
  rescue Pundit::NotAuthorizedError
    @user.errors.add :base, :not_authorized
    @status = :forbidden
  end

  def add_max_users_errors
    if params[:user][:profile_type] == "user" || params[:user][:improver_profile_type] == "user"
      @user.errors.add :max_simple_user, t("helpers.users.errors.paying_customer.max_simple_user")
    else
      @user.errors.add :max_power_user, t("helpers.users.errors.paying_customer.max_power_user")
    end
  end
end
