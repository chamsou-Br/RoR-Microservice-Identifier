# frozen_string_literal: true

# == Schema Information
#
# Table name: groupdocuments
#
#  id          :integer          not null, primary key
#  uid         :string(255)
#  customer_id :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#
# Indexes
#
#  index_groupdocuments_on_customer_id  (customer_id)
#

##
# A `Groupdocument` contains and manage all versions of a specific `Document`.
# Hence, the history of a document is just all documents contained in its `Groupdocument`.
#
# Some rules:
# - A new `Groupdocument` is created only when a brand new `Document` is created.
# - A `Groupdocument` can contain only one `Document` in the publishing procress, in road to be `applicable`.
# - A `Groupdocument` can contain only one `applicable` document. It archives the predecessors.
#
# FIXME: `Groupdocument` is a misleading name, `DocumentHistory` or `DocumentVersions` would have been more appropriate.
#
# @note It replaces the deprecated `parent/child` semantic for versioning.
#       This is mostly because we must be able to create a new version
#       of a graph from any version of it.
#
class Groupdocument < ApplicationRecord
  has_many :documents, dependent: :destroy
  belongs_to :customer

  before_create :generate_uid

  before_destroy do
    elements_from.update_all(model_id: nil, model_type: nil, title_color: "rgb(0,0,0)", italic: false)
  end

  def elements_from
    Element.where(model_id: id, model_type: "Groupdocument", graph_id: customer.graphs)
  end

  def title
    last_available.title
  end

  def as_json(options = {})
    h = super(options)
    h[:title] = title
    h
  end

  def last_available
    documents.last
  end

  def last_active_available
    documents.where.not(state: "deactivated").last
  end

  def applicable_version
    documents.where(state: "applicable").last
  end

  def applicable_version_or_last_available
    applicable_version || last_available
  end

  def applicable_version_or_last_active_available
    applicable_version || last_active_available
  end

  ##
  # Return all document that can be linked to a graph.
  # Those are active documents of the current customer.
  #
  # @note This is mostly used when drawing a graph
  #
  def self.documents_linkable(customer)
    customer.groupdocuments.includes(:documents)
            .where.not(documents: { state: %w[deactivated archived] })
  end

  def generate_uid(start_from = nil)
    # De la forme "<RAILS_ENV>-<TimeStamp>-<Groupdocument.count+1>"
    # Ainsi la probabilité d'en avoir 2 identiques est très faible, même dans le
    # cas de 2 imports sur 2 environnements VM différents.
    return if uid.present?

    i = start_from.nil? ? Groupdocument.count : start_from
    # TODO: Refactor `generate_uid` to use Kernel#loop with break
    # rubocop:disable Lint/Loop
    begin
      i += 1
      self.uid = "#{Rails.env}-#{Time.now.to_i}-#{i}"
    end while Groupdocument.exists?(uid: uid)
    # rubocop:enable Lint/Loop
  end
end
