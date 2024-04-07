# frozen_string_literal: true

# == Schema Information
#
# Table name: process_notifications
#
#  id                :integer          not null, primary key
#  sender_id         :integer
#  receiver_id       :integer
#  message           :text(65535)
#  checked_at        :datetime
#  created_at        :datetime         not null
#  updated_at        :datetime         not null
#  title             :string(255)
#  notification_type :string(255)      default("information")
#
# Indexes
#
#  index_process_notifications_on_receiver_id  (receiver_id)
#  index_process_notifications_on_sender_id    (sender_id)
#

class ProcessNotification < ApplicationRecord
  # @!attribute [rw] user
  #   @returun [User]
  # There is no user_id to back this association up
  # belongs_to :user

  # @!attribute [rw] receiver
  #   @return [User]
  belongs_to :receiver, class_name: "User"

  # @!attribute [rw] sender
  #   @return [User]
  belongs_to :sender, class_name: "User"

  attr_accessor :extra_message

  validates :notification_type, inclusion: { in: %w[information action] }

  has_many :favorites, as: :favorisable, dependent: :destroy
  has_many :likers, through: :favorites, source: :user

  after_initialize do
    @extra_message = nil
  end

  after_create :notify_user

  def notify_user
    if notification.extra_message.nil?
      NotificationMailer.notify_user(notification).deliver
    else
      NotificationMailer.notify_user(notification, notification.extra_message).deliver
    end
  end

  # TODO: Move `self.types` to class constant and change references to this
  # method
  def self.types
    %w[information action]
  end

  def read?
    checked_at?
  end

  def read!
    update_attribute(:checked_at, DateTime.now)
  end

  def unread!
    update_attribute(:checked_at, nil)
  end

  # TODO: Find a better way for generating link in notifications.
  def self.link_to_entity(sender, wf_entity)
    url = "http://#{sender.customer.url}#{workflow_entity_path(wf_entity)}"
    "<a href='#{url}'>#{wf_entity.title}</a>"
  end

  def self.link_to_entity_contribution(sender, wf_entity, contribution)
    url = "http://#{sender.customer.url}#{workflow_entity_path(wf_entity, contribution)}"
    "<a href='#{url}'>#{wf_entity.title}</a>"
  end

  def self.workflow_entity_path(wf_entity, contribution = nil)
    location = wf_entity.instance_of?(Document) ? "documents" : "graphs"
    show_properties_needed = wf_entity.instance_of?(Document) ? "/show_properties" : ""
    path = "/#{location}/#{wf_entity.id}#{show_properties_needed}"
    if contribution.present?
      "#{path}?contribution=#{contribution.id}"
    else
      path
    end
  end

  # TODO: Remove `improver?` returning literal `false` unless required
  # If required, document why here
  def improver?
    # Pour empêcher un plantage entre ancien et nouveau système...
    false
  end
end
