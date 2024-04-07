# frozen_string_literal: true

# == Schema Information
#
# Table name: resources
#
#  id                  :integer          not null, primary key
#  title               :string(255)
#  url                 :text(65535)
#  customer_id         :integer
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  author_id           :integer
#  resource_type       :string(255)
#  purpose             :text(65535)
#  logo                :string(255)
#  deactivated         :boolean          default(FALSE)
#  imported_package_id :integer
#
# Indexes
#
#  index_resources_on_author_id      (author_id)
#  index_resources_on_customer_id    (customer_id)
#  index_resources_on_resource_type  (resource_type)
#  index_resources_on_title          (title)
#  index_resources_on_updated_at     (updated_at)
#

class Resource < ApplicationRecord
  # Elasticsearch
  include SearchableResource
  include LogoFile
  include EntityExporter
  include Sanitizable

  sanitize_fields :title, :purpose, :resource_type

  belongs_to :customer
  # @!attribute [rw] author
  #   @return [User]
  belongs_to :author, foreign_key: "author_id", class_name: "User"

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  has_many :favorites, as: :favorisable, dependent: :destroy
  has_many :likers, through: :favorites, source: :user

  has_many :resource_elements, -> { where shape: ["resource"] }, class_name: "Element",
                                                                 foreign_key: "model_id",
                                                                 dependent: :restrict_with_error

  validates :title, presence: true, uniqueness: { scope: :customer_id }
  validates :author, presence: true
  validates :customer, presence: true
  validates :purpose, length: { maximum: 765 }
  validates :url, length: { maximum: 2083 }

  # @!group Scopes

  # @!method active
  #   @!scope class
  #   @return [ActiveRecord::Relation<Resource>]
  #     Resources that have not been deactivated
  scope :active, -> { where(deactivated: false) }

  # @!method inactive
  #   @!scope class
  #   @return [ActiveRecord::Relation<Resource>]
  #     Resources that have been deactivated
  scope :inactive, -> { where(deactivated: true) }

  # @!endgroup

  # rubocop:disable Naming/PredicateName
  # TODO: Rename `is_linked_to_graphelement?` to `linked_to_graph_element?`
  def is_linked_to_graphelement?
    resource_elements.any?
  end
  # rubocop:enable Naming/PredicateName

  def absolute_url
    url.blank? ? "" : url
  end

  #
  # @return The public URL of this resource.
  #
  def own_url
    Rails.application.routes.url_helpers.url_for(
      controller: :resources,
      action: :show,
      id: id,
      only_path: false,
      protocol: "https",
      host: customer.url
    )
  end

  # TODO: Use double splat instead of options and pass to super
  def to_json(_options = {})
    super(methods: :absolute_url)
  end

  # begin interactions
  def linked_graphs
    customer.graphs.where.not(state: %w[deactivated archived])
            .includes(:elements)
            .where(elements: {
                     type: self.class.name,
                     model_id: id,
                     model_type: self.class.name
                   })
            .references(:elements)
  end
  # end

  KEYS = %w[
    title type description created_at updated_at tags url
  ]

  SPECIAL_KEYS = {
    type: ->(e) {e.resource_type},
    description: ->(e) {e.purpose},
    created_at: ->(e) { e.created_at.strftime("%Y-%m-%d") },
    updated_at: ->(e) { (e.updated_at.strftime("%Y-%m-%d")) },
    tags: ->(e) { (e.tags.pluck(:label).join(",")) },
    url: ->(e) {e.own_url}
  }

  def self.default_export_keys
    [KEYS, SPECIAL_KEYS]
  end


  # rubocop: disable Metrics/MethodLength
  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      # Colonnes csv :
      # Titre, type, description, date de création, date de mise à jour, tags

      resources_array = all.map do |resource|
        [
          resource.title,
          resource.resource_type,
          resource.purpose,
          resource.created_at.strftime("%Y-%m-%d"),
          resource.updated_at.strftime("%Y-%m-%d"),
          resource.tags.pluck(:label).join(","),
          resource.own_url
        ]
      end

      # Gestion des columns
      columns_array = []
      %w[title type description created_at updated_at tags url].each do |resource_attr|
        columns_array << I18n.t("resources.csv.columns.#{resource_attr}")
      end

      # Insertion dans le csv:
      csv << columns_array
      resources_array.each do |resource_array|
        csv << resource_array
      end
    end
  end
  # rubocop: enable Metrics/MethodLength

  # rubocop:disable Naming/PredicateName
  # TODO: Rename `is_deactivate?` to `deactivated?`
  def is_deactivated?
    deactivated
  end

  def update_linked_elements
    Element.where(shape: "resource", type: "resource", model_type: self.class, model_id: id, logo: true)
           .update_all(logo: false)
  end

  # TODO: Rename `has_any_graphs_in_application?` to `graphs_in_application?`
  def has_any_graphs_in_application?
    linked_graphs.where(graphs: { state: "applicable" }).any?
  end
  # rubocop:enable Naming/PredicateName
end
