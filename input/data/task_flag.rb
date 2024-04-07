# frozen_string_literal: true

# == Schema Information
#
# Table name: task_flags
#
#  id            :integer          not null, primary key
#  user_id       :integer
#  taskable_id   :integer
#  taskable_type :string(255)
#  important     :boolean
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class TaskFlag < ApplicationRecord
  belongs_to :user
  belongs_to :taskable, polymorphic: true

  validates :taskable, :user, presence: true

  def self.entity_important?(user, entity)
    task_flag = user.task_flags.find_by(taskable: entity, important: true)
    return false if task_flag.nil?

    task_flag.important
  end

  def self.entity_markable?(entity)
    markable_entities.include?(entity.pluralize)
  end

  # TODO: Move `self.markable_entities` to class constant
  def self.markable_entities
    %w[graphs documents events acts audits]
  end
end
