# frozen_string_literal: true

# == Schema Information
#
# Table name: favorites
#
#  id               :integer          not null, primary key
#  user_id          :integer
#  favorisable_id   :integer
#  favorisable_type :string(255)
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#
# Indexes
#
#  index_favorites_on_favorisable_id_and_favorisable_type  (favorisable_id,favorisable_type)
#  index_favorites_on_user_id                              (user_id)
#

class Favorite < ApplicationRecord
  belongs_to :favorisable, polymorphic: true
  belongs_to :user

  validates :user_id, uniqueness: { scope: %i[favorisable_id favorisable_type] }

  def self.duplicate_for(graph_duplicated, graph_template = nil)
    graph_template = graph_duplicated.parent if graph_template.nil?
    graph_template.favorites.each do |favorite|
      favorite_duplicated = favorite.dup
      favorite_duplicated.favorisable = graph_duplicated
      favorite_duplicated.save
    end
  end

  def self.association_favorisable?(association)
    favorisable_associations.include?(association)
  end

  # TODO: Move `self.favorisable_associations` to class constant
  def self.favorisable_associations
    %w[graphs directories resources roles documents process_notifications new_notifications]
  end
end
