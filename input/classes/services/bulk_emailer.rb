# frozen_string_literal: true

# The class is responsible assembling the required bits and sending the
# corresponding notifications.
#
# @note: this logic is similar to that found in
# NewNotification.cron_call_scheduled_notify_users
# here extracted away on a service in the aim of separating responsibilities.
#
# TODO: this is still WIP
class BulkEmailer
  def self.process_bulk_notifications
    puts "Checking in from the bulk processing..."

    # find all the timezones
    time_zones = (User.time_zones + CustomerSetting.time_zones).uniq

    time_zones.each do |time_zone|
      process_daily_users(time_zone)
      process_weekly_users(time_zone)
    end
  end

  # Steps:
  # 1. With the timezone, find if now is the time_zone_hour
  # 2. Find the daily_users with this hour
  # 3. Iterate through the list of daily_users, and for each user:
  # 4. Find all the notifications that have not been mailed
  # (5. Deliver them now)
  # 5. Call the sidekid scheduler on notifications to:
  # 5.1. send them
  # 5.2. udpate mailed and frequency on notifications.
  #
  def self.process_daily_users(time_zone)
    time_zone_hour = Time.now.in_time_zone(time_zone).hour

    daily_users = User.active.with_time_zone(time_zone)
                      .with_mail_frequency_params("daily", time_zone_hour)

    daily_users.each do |user|
      notifications = Notification.mailable.where(target: user)

      Notification.deliver(notifications, :email,
                           action: :bulk_email,
                           frequency: "daily")
    end
  end

  # Steps:
  # 1. With the timezone, find if now is the time_zone_hour.
  # 2. With the timezone, find if today is the time_zone_day.
  # 3. Find the weekly_users with this hour and day
  # 4. Iterate through the list of weekly_users, and for each user:
  # 5. Find all the notifications that have not been mailed
  # (6. Deliver them now)
  # 6. Call the sidekid scheduler on notifications to:
  # 6.1. send them
  # 6.2. udpate mailed and frequency on notifications.
  #
  def self.process_weekly_users(time_zone)
    time_zone_hour = Time.now.in_time_zone(time_zone).hour
    time_zone_day = Time.now.in_time_zone(time_zone).wday

    weekly_users = User.active.with_time_zone(time_zone)
                       .with_mail_frequency_params("weekly",
                                                   time_zone_hour,
                                                   time_zone_day)

    weekly_users.each do |user|
      notifications = Notification.mailable.where(target: user)

      Notification.deliver(notifications, :email,
                           action: :bulk_email,
                           frequency: "weekly")
    end
  end
end
