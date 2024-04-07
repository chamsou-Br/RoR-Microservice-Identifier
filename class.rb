# frozen_string_literal: true

require "code_mapper"

 CodeMapper.trace do

      @user = current_customer.users.find_by_emergency_token(params[:token]) || User.new

      unless @user.process_admin_owner?
        @user.errors.add :base, :not_owner_or_emergency_token_invalid
        return render :confirm_link
      end

      unless @user.valid_emergency_token?
        @user.errors.add :base, :emergency_token_expired
        return render :confirm_link
      end

      @emergency_access = @user.clear_emergency_token

      flash[:success] = "Successfully sign in by using emergency access"
      sign_in_and_redirect @user, event: :authentication

end
