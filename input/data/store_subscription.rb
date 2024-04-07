# frozen_string_literal: true

# == Schema Information
#
# Table name: store_subscriptions
#
#  id              :integer          not null, primary key
#  user_id         :integer
#  subscription_id :integer
#  enabled         :boolean          default(FALSE)
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_store_subscriptions_on_subscription_id              (subscription_id)
#  index_store_subscriptions_on_user_id                      (user_id)
#  index_store_subscriptions_on_user_id_and_subscription_id  (user_id,subscription_id) UNIQUE
#

class StoreSubscription < ApplicationRecord
  belongs_to :user, required: true
  belongs_to :subscription, required: true, class_name: "Customer"

  validates :enabled, inclusion: { in: [true, false] }
  validates :subscription_id, uniqueness: { scope: :user_id, message: "already subscribed" }
  validate :no_loop_subscription

  private

  def no_loop_subscription
    return unless user_id && subscription_id && user.customer.id == subscription_id

    errors.add(:subscription_id, "cannot subscribe to itself")
  end
end
