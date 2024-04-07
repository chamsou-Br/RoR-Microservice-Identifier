# frozen_string_literal: true

class InvitationsController < Devise::InvitationsController
  def create
    authorize current_user, :invite_users?
    self.resource = invite_resource
    if resource.errors.empty?
      resource.invite!(current_inviter)
      flash_x_success I18n.t("devise.invitations.send_instructions", email: resource.email)
    else
      respond_with_navigational(resource) { render :new }
    end
  rescue StandardError
    flash_x_error I18n.t("errors.operation_failed"), :method_not_allowed
  end

  def send_invitation
    @user = current_customer.users.find(params[:id])
    authorize current_user, :invite_users?
    @user.invite!
    respond_to do |format|
      format.js do
        @user.invitation_sent_at &&
          flash_x_success(I18n.t("devise.invitations.send_instructions", email: @user.email))
      end
    end
  rescue StandardError
    flash_x_error I18n.t("errors.operation_failed"), :method_not_allowed
  end

  def send_all_invitations
    authorize current_user, :invite_users?
    users = current_customer.users.where.not(invitation_token: nil, deactivated: true)
    users.each do |user|
      SendInvitationWorker.perform_async(user.id)
    end
    respond_to do |format|
      format.js do
        flash_x_success I18n.t("devise.invitations.being_sent", count: users.count)
        head :ok
      end
    end
  rescue StandardError
    flash_x_error I18n.t("errors.operation_failed"), :method_not_allowed
  end

  protected

  def invite_resource
    authorize current_inviter, :invite_users?
    new_user = resource_class.new(invite_params) do |u|
      u.customer = current_customer
      u.randomize_password
      u.time_zone = current_customer.time_zone
      u.language = current_customer.language
    end

    if current_customer.can_add_user?(new_user)
      new_user.save
    elsif new_user.power_user?
      new_user.errors.add :base,  t("helpers.users.errors.paying_customer.max_power_user")
    else
      new_user.errors.add :base,  t("helpers.users.errors.paying_customer.max_simple_user")
    end

    new_user
  end
end
