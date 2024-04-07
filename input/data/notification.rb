# frozen_string_literal: true

# == Schema Information
#
# Table name: notifications
#
#  id               :bigint(8)        not null, primary key
#  target_type      :string(255)
#  target_id        :bigint(8)
#  object_type      :string(255)
#  object_id        :bigint(8)
#  read             :boolean          default(FALSE), not null
#  metadata         :text(65535)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  sender_id        :integer
#  type             :string(255)
#  mailed_date      :datetime
#  mailed_frequency :integer
#  checked_at       :datetime
#
# Indexes
#
#  index_notifications_on_object_type_and_object_id  (object_type,object_id)
#  index_notifications_on_read                       (read)
#  index_notifications_on_target_type_and_target_id  (target_type,target_id)
#
class Notification < NotificationHandler::Notification
  belongs_to :sender,
             foreign_key: "sender_id",
             class_name: "User",
             optional: true

  enum mailed_frequency: { do_not_email: 0,
                           real_time: 1,
                           daily: 2,
                           weekly: 3 }

  scope :mailable, -> { where(mailed_date: nil, mailed_frequency: nil) }

  def self.send_with(receiver:, entity:, sender: nil, **opts)
    case entity
    when Risk
      # create a Notification
      entity.create_and_deliver(receiver: receiver,
                                sender: sender,
                                metadata: { role: opts[:role],
                                            category: opts[:category],
                                            comment: opts[:comment] })

    when Act, Audit, Event
      NewNotification.create_and_deliver({ from: sender,
                                           to: receiver,
                                           category: opts[:category],
                                           customer: opts[:customer],
                                           entity: entity }, opts[:comment])
    when Document, Graph
      # create a ProcessNotification
    else
      raise ArgumentError, "Do not know how to send a notification about an "\
                           "object of class #{entity.class}."
    end
  end

  # @note This method is used in `app/services/bulk_emailer.rb` by the methods
  # `process_[daily,weekly]_users` called by `process_bulk_notifications`
  # which have been tested.
  #
  # The purpose of this method is to send bulk emails.
  # This method is a copy of the instance methods used by the gem.
  #
  def self.deliver(notifications, delivery_method, options)
    delivery_method = NotificationPusher::DeliveryMethodConfiguration
                      .find_by_name!(delivery_method)
    delivery_method.call(
      notifications,
      options.merge(notifications: notifications)
    )
  end

  # This method is used in
  # `app/views/notifications/notification/_actionmailer.html.erb` to provide
  # the content of the email to the view, based on the data of the notifcation.
  #
  # rubocop:disable Metrics/AbcSize: Assignment Branch Condition
  def params_for_email
    params = {}
    params[:user_locale] = target.language.to_sym || I18n.locale

    params[:category] = metadata[:category]
    params[:entity_name] = object_type.constantize.model_name.human(
      locale: params[:user_locale]
    )
    # `full_sender` is misleading, as this user is not the actual
    # sender of the email but the triggerer of the aciton.
    # However the name seems to be coming from the legacy code.
    #
    params[:full_sender] = "#{sender.name.full} (#{sender.email})"
    params[:full_url] = object.full_url
    params[:role] = metadata[:role]
    params[:title] = object.my_description
    params[:translated_role] =
      I18n.t("user_responsibility.#{params[:role]}.one", locale: params[:user_locale])
    params
  end
  # rubocop:enable Metrics/AbcSize: Assignment Branch Condition
end
