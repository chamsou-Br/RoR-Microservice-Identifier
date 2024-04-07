# frozen_string_literal: true

# == Schema Information
#
# Table name: groupgraphs
#
#  id               :integer          not null, primary key
#  uid              :string(255)
#  customer_id      :integer
#  type             :string(255)
#  level            :integer
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  root             :boolean          default(FALSE)
#  tree             :boolean          default(FALSE)
#  auto_role_viewer :boolean          default(FALSE)
#  review_enable    :boolean          default(FALSE)
#  review_date      :date
#  review_reminder  :integer
#
# Indexes
#
#  index_groupgraphs_on_customer_id  (customer_id)
#

##
# A `Groupgraph` contains and manage all versions of a specific `Graph`.
# Hence, the history of a graph is just all graphs contained in its `Groupgraph`.
#
# Some rules:
# - A new `Groupgraph` is created only when a brand new `Graph` is created (from scratch or from duplication).
# - A `Groupgraph` can contain only one `Graph` in the publishing procress, in road to be `applicable`.
# - A `Groupgraph` can contain only one `applicable` graph. It archives the predecessors.
#
# FIXME: `Groupgraph` is a misleading name, `GraphHistory` or `GraphVersions` would have been more appropriate.
#
# @note It replaces the deprecated `parent/child` semantic for versioning.
#       This is mostly because we must be able to create a new version
#       of a graph from any version of it.
#
# TODO: Refactor `Groupgraph` using some included modules for date diffing, etc.
class Groupgraph < ApplicationRecord
  self.inheritance_column = nil

  has_many :graphs, dependent: :destroy
  belongs_to :customer

  has_many :review_histories
  has_many :reminders, as: :remindable

  enum review_reminder: { one_week_before: 1, two_week_before: 2, one_month_before: 3, three_month_before: 4 }

  validates :level, inclusion: { in: [1, 2, 3] }
  validates :type, inclusion: { in: %w[process human environment] }
  validates :review_reminder, inclusion: { in: Groupgraph.review_reminders.keys }, allow_nil: true
  validates :review_date, presence: true, on: :update, if: proc { |groupgraph| groupgraph.review_enable }

  validate :check_review_date

  before_create :generate_uid

  after_commit :set_reminders, on: :update

  before_destroy do
    # On efface le lien du groupgraph à détruire dans tous les graphs ayant des shapes lié à lui
    elements_from.update_all(model_id: nil, model_type: nil, title_color: "rgb(0,0,0)", italic: false)
  end

  def elements_from
    Element.where(model_id: id, model_type: "Groupgraph", graph_id: customer.graphs)
  end

  def title
    last_available.title
  end

  def as_json(options = {})
    h = super(options)
    h[:title] = title
    h
  end

  # TODO: Move `self.types` to a class constant and replace where it is used
  def self.types
    ["process"]
  end

  # TODO: Move `self.levels` to a class constant and replace where it is used
  def self.levels
    [1, 2, 3]
  end

  def last_available
    graphs.last
  end

  def last_active_available
    graphs.where.not(state: "deactivated").last
  end

  def applicable_version
    graphs.where(state: "applicable").last
  end

  def applicable_version_or_last_available
    applicable_version || last_available
  end

  def applicable_version_or_last_active_available
    applicable_version || last_active_available
  end

  ##
  # Return all graphs that can be linked to the specified one.
  # Those are active graphs that are different from this one.
  #
  # @note This is mostly used when drawing a the `from_graph` graph
  #
  def self.graphs_linkable(from_graph, param_type, param_level)
    from_graph.customer.groupgraphs.includes("graphs").where
              .not(id: from_graph.groupgraph.id, graphs: { id: nil, state: %w[deactivated archived] })
              .where(type: param_type, level: param_level)
  end

  def set_reminders
    change_previous_notification_of_reminders
    reminders.destroy_all

    return unless review_enable

    reminders.create(to: last_available.author, occurs_at: review_date,
                     reminds_at: remind_date, reminder_type: "graph_review_date")
    unless last_available.pilot.nil?
      reminders.create(to: last_available.pilot, occurs_at: review_date,
                       reminds_at: remind_date, reminder_type: "graph_review_date")
    end

    reminders.each(&:perform)
  end

  # TODO: Refactor `remind_date` to use date diff map to get previous date
  # used for review_graph reminder
  def remind_date
    return nil unless review_enable

    res = case review_reminder
          when "one_week_before"
            review_date.prev_day(7)
          when "two_week_before"
            review_date.prev_day(14)
          when "one_month_before"
            review_date.prev_month(1)
          when "three_month_before"
            review_date.prev_month(3)
          end

    today = Date.today
    res < today ? today.to_datetime : res
  end

  def generate_uid(start_from = nil)
    # De la forme "<RAILS_ENV>-<TimeStamp>-<Groupgraph.count+1>"
    # Ainsi la probabilité d'en avoir 2 identiques est très faible, même dans le
    # cas de 2 imports sur 2 environnements VM différents.
    return if uid.present?

    i = start_from.nil? ? Groupgraph.count : start_from
    # TODO: Refactor `generate_uid` to use Kernel#loop with break after writing
    # tests
    # rubocop:disable Lint/Loop
    begin
      i += 1
      self.uid = "#{Rails.env}-#{Time.now.to_i}-#{i}"
    end while Groupgraph.exists?(uid: uid)
    # rubocop:enable Lint/Loop
  end

  private

  # TODO: Refactor `check_review_date` into 2 smaller private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def check_review_date
    # return unless !changes[:review_date].nil? && changes[:review_date].uniq.count > 1
    return unless !changes_to_save[:review_date].nil? && changes_to_save[:review_date].uniq.count > 1

    if !review_date.nil? && !review_histories.blank? && review_date == review_histories.last.review_date
      errors.add(:review_date, :cannot_be_equal_to_last_review)
      return false
    end

    return unless !review_date.nil? && review_date < Date.today

    errors.add(:review_date, :cannot_be_in_the_past)
    false
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  def change_previous_notification_of_reminders
    NewNotification.transaction do
      NewNotification.where(category: NewNotification.categories[:reminder_graph_review_date],
                            entity_type: "Reminder",
                            entity_id: reminders).each do |n|
        Rails.logger.info "change previous NewNotication #{n.id} to redirect to current active graph"
        n.category = NewNotification.categories[:reminder_graph_review_date_changed]
        n.entity = applicable_version_or_last_available
        n.save
      end
    end
  end
end
