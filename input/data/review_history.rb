# frozen_string_literal: true

# == Schema Information
#
# Table name: review_histories
#
#  id            :integer          not null, primary key
#  review_date   :date
#  reviewer_id   :integer
#  groupgraph_id :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#

class ReviewHistory < ApplicationRecord
  belongs_to :groupgraph
  belongs_to :reviewer, class_name: "User"
end
