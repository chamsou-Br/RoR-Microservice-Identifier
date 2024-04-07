# frozen_string_literal: true

# == Schema Information
#
# Table name: store_connections
#
#  id            :integer          not null, primary key
#  customer_id   :integer
#  connection_id :integer
#  enabled       :boolean          default(FALSE)
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_store_connections_on_connection_id                  (connection_id)
#  index_store_connections_on_customer_id                    (customer_id)
#  index_store_connections_on_customer_id_and_connection_id  (customer_id,connection_id) UNIQUE
#

class StoreConnection < ApplicationRecord
  # TODO: there are some tests explicitly testing creation with empty
  # connections. Once we can activate the following line:
  # ActiveRecord::Base.belongs_to_required_by_default = true
  # we can uncomment the 2 following and delete the 2 after.
  #
  # belongs_to :customer
  # belongs_to :connection, class_name: "Customer"

  belongs_to :customer, required: true
  belongs_to :connection, required: true, class_name: "Customer"

  validates :enabled, inclusion: { in: [true, false] }
  validates :connection, uniqueness: { scope: :customer }
  validate :no_loop_connection

  def accept!
    raise "already connected" if enabled?

    StoreConnection.transaction do
      StoreConnection.create(
        customer_id: connection_id,
        connection_id: customer_id,
        enabled: true
      )
      self.enabled = true
      save!
    end
  end

  def reject!
    raise "already connected" if enabled?

    disconnect!
  end

  def disconnect!
    StoreConnection.transaction do
      StoreConnection.where(
        customer_id: connection_id,
        connection_id: customer_id,
        enabled: true
      ).destroy_all
      destroy!
    end
  end

  private

  def no_loop_connection
    errors.add(:connection_id, "cannot connect to itself") if customer == connection
  end
end
