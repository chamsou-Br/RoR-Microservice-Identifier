# frozen_string_literal: true

# == Schema Information
#
# Table name: graph_steps
#
#  id         :integer          not null, primary key
#  graph_id   :integer
#  set        :text(16777215)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class GraphStep < ApplicationRecord
  has_one :graph

  def set_content
    if set.nil? || !set.starts_with?("[") || !set.ends_with?("]")
      nil
    else
      set[1..(set.length - 2)]
    end
  end
end
