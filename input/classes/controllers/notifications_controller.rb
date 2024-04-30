# frozen_string_literal: true

# rubocop: disable all
class NotificationsController < ApplicationController
  include Listable
  include NotificationsHelper

  before_action :destroy_invalid_notifications, only: %i[index preview]

  def index
    respond_to do |format|
      format.html {}
      format.json do
        render_list 'all',
                    :list_index_definition,
                    favor: true,
                    author: %i[from sender]
      end
    end
  end

  def preview
    respond_to do |format|
      format.html { render partial: 'header/notification' }
      format.json { render_list 'all', :list_preview_definition, author: %i[from sender] }
    end
  end

  def delete
    notifications = list_selection(:list_index_definition)
    if notifications
      destroyed = notifications.map { |n| n.destroy.destroyed? } - [false]
      flash_x_success I18n.t('controllers.notifications.successes.delete', count: destroyed.count) if destroyed.count
    else
      flash_x_error I18n.t('controllers.notifications.errors.delete')
    end
  end

  def mark_read
    notifications = list_selection(:list_index_definition)
    notifications&.each(&:read!)
  end

  # Old means the previous mechanism
  def mark_read_old
    notification = current_user.process_notifications.find(params[:id])
    notification.read!
    head :ok
  end

  def mark_all_read
    current_user.unread_notifications.each(&:read!)
  end

  def mark_unread
    notifications = list_selection(:list_index_definition)
    notifications&.each(&:unread!)
  end

  def refresh_counter
    @notifications = current_user.process_notifications.where(checked_at: nil)
    logger.debug @notifications.count.to_s
    respond_to do |format|
      format.json { render json: { counter: @notifications.count.to_json } }
    end
  end

  def follow
    notification = NewNotification.find(params[:id])
    if notification.to != current_user
      render_403
      return
    end

    notification = current_user.new_notifications.find(params[:id])
    notification.read! unless notification.read?

    not_found if notification.entity_path.blank?
    redirect_to notification.entity_path
  end

  private

  def destroy_invalid_notifications
    NotifierService.new(user: current_user, entity: nil).destroy_invalid_notifications
  end

  def list_index_definition
    {
      items: lambda {
        current_user.process_notifications.includes(:sender) +
          current_user.new_notifications.includes(:from)
      },
      tabs: {
        action: ->(ns) { ns.select { |n| notification_type(n) == 'action' } },
        information: ->(ns) { ns.select { |n| notification_type(n) == 'information' } },
        favored: ->(ns) { ns.select { |n| n.likers.include?(current_user) } },
        all: ->(ns) { ns }
      },
      orders: {
        created: ->(ns) { order_by_created_at(ns) },
        read: ->(ns) { order_by_checked_at_inv(ns) },
        unread: ->(ns) { order_by_checked_at(ns) },
        from: ->(ns) { order_by_from(ns) },
        title: ->(ns) { order_by_body(ns) },
        title_inv: ->(ns) { order_by_body_inv(ns) }
      }
    }
  end

  def list_preview_definition
    {
      items: lambda {
        order_by_created_at(current_user.process_notifications + current_user.new_notifications)
      }
    }
  end

  def order_by_created_at(ns)
    ns.sort do |n1, n2|
      compare = (n2.created_at || 10.years.ago) <=> (n1.created_at || 10.years.ago)
      compare.zero? ? notification_body(n1) <=> notification_body(n2) : compare
    end
  end

  def order_by_checked_at_inv(ns)
    ns.sort do |n1, n2|
      compare = (n2.checked_at || 10.years.ago) <=> (n1.checked_at || 10.years.ago)
      compare.zero? ? notification_body(n1) <=> notification_body(n2) : compare
    end
  end

  def order_by_checked_at(ns)
    ns.sort do |n1, n2|
      compare = (n1.checked_at || 10.years.ago) <=> (n2.checked_at || 10.years.ago)
      compare.zero? ? notification_body(n1) <=> notification_body(n2) : compare
    end
  end

  def order_by_from(ns)
    ns.sort do |n1, n2|
      compare = (n1.is_a?(NewNotification) ? n1.from : n1.sender) <=>
                (n2.is_a?(NewNotification) ? n2.from : n2.sender)
      # compare may be nil because the optional from property of the NewNotification model is nil
      if compare.nil?
        n1.is_a?(NewNotification) && n1.from ? (n2.is_a?(NewNotification) && n2.from ? 0 : 1) : -1
      else
        compare.zero? ? notification_body(n1) <=> notification_body(n2) : compare
      end
    end
  end

  def order_by_body(ns)
    ns.sort { |n1, n2| notification_body(n1) <=> notification_body(n2) }
  end

  def order_by_body_inv(ns)
    ns.sort { |n1, n2| notification_body(n2) <=> notification_body(n1) }
  end
end
# rubocop: enable all
