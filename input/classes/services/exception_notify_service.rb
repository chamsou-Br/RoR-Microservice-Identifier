# frozen_string_literal: true

# This class is responsible for sending manual exception reports it wraps our
# dependency on ExceptionNotifier gem and could be used for other systems
#
class ExceptionNotifyService
  def self.notify(exception, message)
    ExceptionNotifier.notify_exception(
      exception,
      env: Rails.env, data: { message: message }
    )
  end
end
