# frozen_string_literal: true

# Provides a custom i18n message when a user gets locked
# That message includes a number of minutes left until unlocked
class DeviseCustomFailure < Devise::FailureApp
  def i18n_message(default = nil)
    message = warden_message || default || :unauthenticated
    if message == :locked && request.params[:user][:email]
      I18n.t("devise.failure.locked",
             delay: calculate_minutes(request.params[:user][:email]))
    elsif message == :locked
      delay = Devise.unlock_in / 60
      I18n.t("devise.failure.locked", delay: delay)
    else
      super
    end
  end

  private

  def calculate_minutes(email)
    user = User.find_by(email: email)
    time_diff = (
      user&.locked_at || Time.zone.now
    ) + Devise.unlock_in - Time.zone.now
    Time.zone.at(time_diff.to_i).min
  end
end
