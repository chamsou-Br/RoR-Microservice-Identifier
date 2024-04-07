# frozen_string_literal: true

# == Schema Information
#
# Table name: recordings
#
#  id           :integer          not null, primary key
#  title        :string(255)
#  url          :string(255)
#  reference    :string(255)
#  customer_id  :integer
#  stock_tool   :string(255)
#  protect_tool :string(255)
#  stock_time   :string(255)
#  destroy_tool :string(255)
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#
# Indexes
#
#  index_recordings_on_customer_id  (customer_id)
#

class Recording < ApplicationRecord
  belongs_to :customer

  validates :title, presence: true
  validates :reference, length: { in: 2..23 }
  validates :customer, presence: true
end
