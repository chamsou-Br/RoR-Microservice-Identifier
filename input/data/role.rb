# frozen_string_literal: true

# == Schema Information
#
# Table name: roles
#
#  id                  :integer          not null, primary key
#  title               :string(255)
#  type                :string(255)
#  created_at          :datetime         not null
#  updated_at          :datetime         not null
#  mission             :string(2300)
#  activities          :string(2300)
#  author_id           :integer
#  writer_id           :integer
#  customer_id         :integer
#  purpose             :string(2300)
#  deactivated         :boolean          default(FALSE)
#  imported_package_id :integer
#
# Indexes
#
#  index_roles_on_author_id    (author_id)
#  index_roles_on_customer_id  (customer_id)
#  index_roles_on_title        (title)
#  index_roles_on_type         (type)
#  index_roles_on_updated_at   (updated_at)
#  index_roles_on_writer_id    (writer_id)
#

class Role < ApplicationRecord
  ## Elasticsearch
  include SearchableRole
  include EntityExporter
  include Sanitizable

  sanitize_fields :title, :purpose, :mission, :activities

  ATTACHMENTS_LIMIT = 10

  # CSV attributes to be used in CSV serialization for column headers.  The
  # order of these is significant as the order in which columns headers present
  # themselves reflects the order of this array.
  CSV_ATTRIBUTES = %w[title type description created_at updated_at tags
                      graphs_count users status url].freeze
  TYPES = %w[intern extern unit].freeze

  KEYS = %w[title type description  created_at updated_at tags graphs_count
   users status url].freeze

  SPECIAL_KEYS = {
    type: lambda { |e|
    I18n.t(e.type, scope: "activerecord.attributes.role.types")
    },
    description: ->(e) {e.purpose},
    created_at: ->(e) { e.created_at.strftime("%Y-%m-%d") },
    updated_at: ->(e) { e.updated_at.strftime("%Y-%m-%d") },
    tags: ->(e) { e.tags.pluck(:label).join(",") },
    graphs_count: ->(e) { e.graphs.nil? ? "" : e.graphs.count },
    users: ->(e) { e.users.map(&:name).map(&:full).join(",") },
    status: ->(e) {I18n.t(e.status, scope: "activerecord.attributes.role.status")}
  }.freeze



  has_many :roles_user, dependent: :destroy
  has_many :users, through: :roles_user

  has_many :role_elements, -> { where shape: %w[role relatedRole] },
           class_name: "Element",
           foreign_key: "model_id",
           dependent: :restrict_with_error

  has_many :graphs_roles
  has_many :graphs, through: :graphs_roles

  has_many :role_attachments, dependent: :destroy
  has_many :attachments, foreign_key: "role_id", class_name: "RoleAttachment"

  validates :type, inclusion: { in: TYPES }
  validates :title,
            presence: true,
            uniqueness: { scope: %i[customer_id type], case_sensitive: true }
  validates :purpose, length: { maximum: 2300 }
  validates :mission, length: { maximum: 2300 }
  validates :activities, length: { maximum: 2300 }

  has_many :taggings, as: :taggable, dependent: :destroy
  has_many :tags, through: :taggings

  # @!attribute [rw] author
  #   @return [User]
  belongs_to :author, foreign_key: "author_id", class_name: "User"

  # @!attribute [rw] writer
  #   @return [User]
  belongs_to :writer, foreign_key: "writer_id", class_name: "User",
                      optional: true

  belongs_to :customer

  has_many :favorites, as: :favorisable, dependent: :destroy
  has_many :likers, through: :favorites, source: :user

  has_many :graphs_viewers, as: :viewer, dependent: :destroy
  has_many :viewable_graphs, through: :graphs_viewers, source: :graph

  has_many :documents_viewers, as: :viewer, dependent: :destroy
  has_many :viewable_documents, through: :documents_viewers, source: :document

  before_validation :set_customer

  # @!group Scopes

  # @!method active
  #   @!scope class
  #   @return [ActiveRecord::Relation<Role>]
  #     Roles that have not been deactivated
  scope :active, -> { where(deactivated: false) }

  # @!method inactive
  #   @!scope class
  #   @return [ActiveRecord::Relation<Role>]
  #     Roles that have been deactivated
  scope :inactive, -> { where(deactivated: true) }

  # @!endgroup

  #
  # @return The public URL of this role.
  #
  def url
    Rails.application.routes.url_helpers.url_for(
      controller: :roles,
      action: :show,
      id: id,
      only_path: false,
      protocol: "https",
      host: customer.url
    )
  end
  
  def self.default_export_keys
    [KEYS, SPECIAL_KEYS]
  end

  # To deprecate: this hook make the validations useless and it should probably
  # not exist in its present form. Such initialization should happen at the
  # controller level or at the GraphQL level.
  # TODO: to be fix for 4.0.0.
  #
  def set_customer
    self.customer = author.customer
  end

  def status
    deactivated ? "deactivated" : "activated"
  end

  self.inheritance_column = nil

  # Returns class constant `CSV_ATTRIBUTES`
  def self.csv_attributes
    CSV_ATTRIBUTES
  end

  # Returns class constant `TYPES`
  def self.types
    TYPES
  end




  # TODO: Extract CSV serialization to a module that accepts an key-value hash
  # of column headers and procs to get values from a given role
  # TODO: enable again the Metrics/AbcSize.
  #       I disabled it because I'll refactor the whole csv export process
  # rubocop:disable Metrics/AbcSize Assignment Branch Condition
  def self.to_csv(options = {})
    CSV.generate(options) do |csv|
      # Create array of translated column header values
      columns_array = CSV_ATTRIBUTES.map do |role_attr|
        I18n.t("roles.csv.columns.#{role_attr}")
      end

      # Insert the initial row of column headers
      csv << columns_array

      # Append each serialized role array to the CSV
      all.each do |role|
        role_array = []
        role_array << role.title
        role_array << I18n.t(role.type, scope: "activerecord.attributes.role.types")
        role_array << role.purpose
        role_array << role.created_at.strftime("%Y-%m-%d")
        role_array << role.updated_at.strftime("%Y-%m-%d")
        role_array << role.tags.pluck(:label).join(",")
        role_array << role.graphs.nil? ? "" : graphs.count
        role_array << role.users.map(&:name).map(&:full).join(",")
        role_array << I18n.t(role.status, scope: "activerecord.attributes.role.status")
        role_array << role.url

        csv << role_array
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  # TODO: Remove `is_deactivated?` once references to it have all been removed
  # rubocop: disable Naming/PredicateName
  def is_deactivated?
    deactivated?
  end

  def activated?
    !deactivated?
  end

  # Rename has_any_graphs_in_application? to any_graphs_in_application?
  def has_any_graphs_in_application?
    graphs.where(state: "applicable").any?
  end
  # rubocop: enable Naming/PredicateName: Rename

  def viewer_of?(entity)
    method_name = "viewable_#{entity.class.name.downcase.pluralize}"

    unless respond_to?(method_name)
      raise NotImplementedError, "Role does not implement `#{method_name}` " \
                                 "as derived by `viewable_` and plural form " \
                                 "of entity class `#{entity.class.name}`"
    end

    send(method_name).include?(entity)
  end
end
