# frozen_string_literal: true

# == Schema Information
#
# Table name: read_confirmations
#
#  id           :integer          not null, primary key
#  process_type :string(255)
#  process_id   :integer
#  user_id      :integer
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#

class ReadConfirmation < ApplicationRecord
  belongs_to :user
  belongs_to :process, polymorphic: true
end
