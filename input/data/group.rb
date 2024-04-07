# frozen_string_literal: true

# == Schema Information
#
# Table name: groups
#
#  id          :integer          not null, primary key
#  title       :string(255)
#  description :text(65535)
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  customer_id :integer
#
# Indexes
#
#  index_groups_on_customer_id  (customer_id)
#  index_groups_on_title        (title)
#  index_groups_on_updated_at   (updated_at)
#

class Group < ApplicationRecord
  # attr_accessible :description, :title

  ### Elasticsearch
  include SearchableGroup
  belongs_to :customer

  include Sanitizable

  sanitize_fields :description

  # Hint: Do NOT move this until rails issue has been fixed!  This callback has
  # to be declared BEFORE graphs_viewer and documents_viewer relationships
  # declaration.
  # rails/issues/3458 related.

  before_destroy do |group|
    graphs_associations = GraphsViewer.where(viewer_type: "Group",
                                             viewer_id: id)
    documents_associations = DocumentsViewer.where(viewer_type: "Group",
                                                   viewer_id: id)
    errors.add(:group_linked,
               I18n.t("controllers.groups.errors.group_linked",
                      title: group.title))
    throw(:abort) if graphs_associations.any? || documents_associations.any?
  end

  has_many :users_group, dependent: :destroy
  has_many :users, through: :users_group

  has_many :graphs_viewers, as: :viewer, dependent: :destroy
  has_many :viewable_graphs, through: :graphs_viewers, source: :graph

  has_many :documents_viewers, as: :viewer, dependent: :destroy
  has_many :viewable_documents, through: :documents_viewers, source: :document

  scope :autocompleter,
        lambda { |query|
          where("title like :q", q: "%#{query}%").order("title ASC")
        }

  validates :title, length: { maximum: 100 },
                    presence: true,
                    uniqueness: { scope: :customer_id }

  #
  # Is the group a viewer of the given `graph`?
  #
  # @param [Graph] graph
  #
  # @return [Boolean]
  #
  def viewer_of?(graph)
    graph.viewergroups.include?(self)
  end

  # TODO: this method does not seem to be in use
  # TODO: Rename `has_user?` to `user?` or `includes?`
  # rubocop:disable Naming/PredicateName
  def has_user?(user)
    users.include?(user)
    # TODO: Do not rescue StandardError
  rescue StandardError
    false
  end
  # rubocop:enable Naming/PredicateName

  def viewable_users_for(user)
    if user.process_admin?
      users
    else
      users.where(deactivated: false)
    end
  end
end
