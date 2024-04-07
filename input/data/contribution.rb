# frozen_string_literal: true

# == Schema Information
#
# Table name: contributions
#
#  id                 :integer          not null, primary key
#  content            :text(65535)
#  contributable_id   :integer
#  contributable_type :string(255)
#  user_id            :integer
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#
# Indexes
#
#  index_contributions_on_contributable_id_and_contributable_type  (contributable_id,contributable_type)
#  index_contributions_on_user_id                                  (user_id)
#

class Contribution < ApplicationRecord
  belongs_to :contributable, polymorphic: true
  belongs_to :user

  validates :content, presence: true

  after_create :send_notifications

  def send_notifications
    contributors = contributable.contributors_and_default_contributors - [user]
    contributors.each do |contributor|
      NewNotification.create_and_deliver({ customer: user.customer,
                                           category: :new_contribution,
                                           from: user,
                                           to: contributor,
                                           entity: self }, content)
    end
  end

  def sanitize_content
    self.content = ActionController::Base.helpers.sanitize(content, scrubber: :strip)
  end
end
