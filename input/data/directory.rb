# frozen_string_literal: true

# == Schema Information
#
# Table name: directories
#
#  id          :integer          not null, primary key
#  name        :string(255)
#  parent_id   :integer
#  lft         :integer
#  rgt         :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  customer_id :integer
#  author_id   :integer
#
# Indexes
#
#  index_directories_on_author_id    (author_id)
#  index_directories_on_customer_id  (customer_id)
#  index_directories_on_parent_id    (parent_id)
#

class Directory < ApplicationRecord
  include Sanitizable
  ## Elasticsearch
  include SearchableDirectory

  acts_as_nested_set
  sanitize_fields :name

  belongs_to :customer
  # @!atribute [rw] author
  #   @return [User]
  belongs_to :author, foreign_key: "author_id", class_name: "User", optional: true

  has_many :graphs
  has_many :documents

  has_many :favorites, as: :favorisable, dependent: :destroy
  has_many :likers, through: :favorites, source: :user

  validates :author, presence: { is: true, if: :parent_id? }
  validates :customer, presence: true
  validates :name, length: { maximum: 100 },
                   presence: true,
                   uniqueness: { scope: %i[parent_id customer_id] }

  def move_to_left_of(right_sibling)
    return false if id == right_sibling.id || !name_uniqueness_within_parent(right_sibling.parent)

    super
  end

  def move_to_right_of(left_sibling)
    return false if id == left_sibling.id || !name_uniqueness_within_parent(left_sibling.parent)

    super
  end

  # array of all archived graphs
  def archived_child_graphs
    array = get_archived_graphs

    children.each do |sub_directory|
      array += sub_directory.archived_child_graphs
    end
    array
  end

  # array of all archived documents
  def archived_child_documents
    array = get_archived_documents

    children.each do |sub_directory|
      array += sub_directory.archived_child_documents
    end
    array
  end

  # rubocop:disable Naming/AccessorMethodName
  # TODO: Rename `get_archived_graphs` to `archived_graphs`
  def get_archived_graphs
    graphs.where(state: "archived").to_a
  end

  # TODO: Rename `get_archived_documents` to `archived_documents`
  def get_archived_documents
    documents.where(state: "archived").to_a
  end
  # rubocop:enable Naming/AccessorMethodName

  def destroy
    if parent_id.nil?
      errors.add(:base, :is_root, name: name)
      return false
    end

    # appel du destroy de la super class
    return super if check_destroy

    false
  end

  # rubocop:disable Metrics/AbcSize
  # TODO: Refactor `check_destroy` into smaller private methods
  def check_destroy
    errors.add(:base, :has_graphs, name: name) if graphs.where.not(state: "archived").count.positive?
    errors.add(:base, :has_documents, name: name) if documents.where.not(state: "archived").count.positive?

    children.each do |child|
      next if child.check_destroy

      child.errors.each do |key, message|
        errors.add(key, message)
      end
    end

    errors.blank? # return false, to not destroy the element, otherwise, it will delete.
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Naming/AccessorMethodName
  # TODO: Rename `get_documents_and_graphs` to `documents_and_graphs`
  def get_documents_and_graphs
    children = []
    children += graphs.reject(&:in_archives?)
    children += documents
    children.sort_by!(&:title)
  end
  # rubocop:enable Naming/AccessorMethodName

  # build a tree of this directory and its subdirectories
  def build_nested_hash
    directories = self_and_descendants

    tree = directories.map do |directory|
      [directory.id, { directory: directory, children: [] }]
    end.to_h

    tree.each do |_id, item|
      parent = tree[item[:directory].parent_id]
      parent[:children] << item if parent
    end

    tree[id]
  end

  private

  def name_uniqueness_within_parent(target_parent)
    target_parent.children.each do |brother|
      errors.add(:name, :taken) if brother.id != id && brother.name.casecmp(name).zero?
    end
    errors.blank? # return false, to not destroy the element, otherwise, it will delete.
  end
end
