# frozen_string_literal: true

# == Schema Information
#
# Table name: tasks
#
#  id          :integer          not null, primary key
#  description :text(65535)
#  result      :text(65535)
#  completed   :boolean
#  act_id      :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#

class Task < ApplicationRecord
  include LinkableFieldable

  belongs_to :act

  validates :description, :result, length: { maximum: 65_535 }
  scope :completed, -> { where(completed: true) }
end
