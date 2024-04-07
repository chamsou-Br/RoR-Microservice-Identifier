# frozen_string_literal: true

# == Schema Information
#
# Table name: timeline_events
#
#  id         :integer          not null, primary key
#  author_id  :integer
#  event_id   :integer
#  object     :text(65535)
#  comment    :string(12000)
#  action     :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  sparse     :boolean          default(TRUE)
#
# Indexes
#
#  index_timeline_events_on_author_id   (author_id)
#  index_timeline_events_on_created_at  (created_at)
#  index_timeline_events_on_event_id    (event_id)
#

class TimelineEvent < ApplicationRecord
  # Re: flag sparse -->  Following from this note's merge
  # (https://gitlab.qualiproto.fr/pyx4/qualipso/merge_requests/2146#note_54283)
  # the sparse flag represents the density of the record according to the
  # mathematical definition of sparse matrix, in which most elements are
  # zero. This was the previous way of storing timeline operations, as
  # oppossed to now, where only the changes are logged.
  #
  # Previous logging: => {"owner_id"=>3,
  #                       "domain_ids"=>[],
  #                       "cause_ids"=>[],
  #                       "act_ids"=>[],
  #                       "localisation_ids"=>[],
  #                       "custom_impacts_ids"=>[],
  #                       "graphs_impact_ids"=>[],
  #                       "documents_impact_ids"=>[],
  #                       "audit_ids"=>[],
  #                       "event_attachment_ids"=>[],
  #                       "continuous_improvement_manager_ids"=>[],
  #                       "validator_ids"=>[],
  #                       "contributor_ids"=>[]}
  # Current logging: => {"owner_id"=>3}

  belongs_to :author, foreign_key: "author_id", class_name: "User"
  belongs_to :event

  validates :object, :action, presence: true
  validates :comment, length: { maximum: 255 }

  # TODO: Rename `is_starting_point` to `starting_point?`
  # rubocop:disable Naming/PredicateName
  def is_starting_point
    action == "create"
  end
  # rubocop:enable Naming/PredicateName

  def next
    event.timeline_items.where("created_at > ?", created_at)
         .order("created_at ASC").first
  end

  def prev
    event.timeline_items.where("created_at <= ? AND id != ?", created_at, id)
         .order("created_at ASC").last
  end

  def content_for(association)
    parsed_object[association.to_s]
  end

  def parsed_object
    @parsed_object ||= JSON.parse(object)
  end

  def association_unchanged?(association)
    return false if prev.nil?

    event.association_tracked?(association) &&
      content_for(association) == prev.content_for(association)
  end

  def association_changed?(association)
    !association_unchanged?(association)
  end
end
