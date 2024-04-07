# frozen_string_literal: true

# == Schema Information
#
# Table name: timeline_acts
#
#  id         :integer          not null, primary key
#  author_id  :integer
#  act_id     :integer
#  object     :text(65535)
#  comment    :string(255)
#  action     :string(255)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  sparse     :boolean          default(TRUE)
#
# Indexes
#
#  index_timeline_acts_on_act_id      (act_id)
#  index_timeline_acts_on_author_id   (author_id)
#  index_timeline_acts_on_created_at  (created_at)
#

class TimelineAct < ApplicationRecord
  # Re: flag sparse -->  Following from this note's merge
  # (https://gitlab.qualiproto.fr/pyx4/qualipso/merge_requests/2146#note_54283)
  # the sparse flag represents the density of the record according to the
  # mathematical definition of sparse matrix, in which most elements are
  # zero. This was the previous way of storing timeline operations, as
  # oppossed to now, where only the changes are logged.
  #
  # Previous logging: => {"owner_id"=>3,
  #                       "domain_ids"=>[],
  #                       "event_ids"=>[],
  #                       "act_attachment_ids"=>[],
  #                       "custom_impacts_ids"=>[],
  #                       "graphs_impact_ids"=>[],
  #                       "documents_impact_ids"=>[],
  #                       "validator_ids"=>[]}
  # Current logging: => {"owner_id"=>3}

  belongs_to :author, foreign_key: "author_id", class_name: "User"
  belongs_to :act

  validates :author, :object, :action, presence: true
  validates :comment, length: { maximum: 255 }

  # TODO: Rename `is_starting_point` to `starting_point?`
  # rubocop:disable Naming/PredicateName
  def is_starting_point
    action == "create"
  end
  # rubocop:enable Naming/PredicateName

  def next
    act.timeline_items.where("created_at > ?", created_at)
       .order("created_at ASC").first
  end

  def prev
    act.timeline_items.where("created_at < ?", created_at)
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

    act.association_tracked?(association) &&
      content_for(association) == prev.content_for(association)
  end

  def association_changed?(association)
    !association_unchanged?(association)
  end
end
