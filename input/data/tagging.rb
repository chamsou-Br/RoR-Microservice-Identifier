# frozen_string_literal: true

# == Schema Information
#
# Table name: taggings
#
#  id            :integer          not null, primary key
#  taggable_id   :integer
#  taggable_type :string(255)
#  tag_id        :integer
#  created_at    :datetime         not null
#  updated_at    :datetime         not null
#
# Indexes
#
#  index_taggings_on_tag_id                         (tag_id)
#  index_taggings_on_taggable_id_and_taggable_type  (taggable_id,taggable_type)
#

class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true
  belongs_to :tag

  after_destroy :update_taggable_index

  def self.duplicate_for(wf_entity_duplicated, wf_entity_template = nil)
    wf_entity_template = wf_entity_duplicated.parent if wf_entity_template.nil?
    wf_entity_template.tags.each do |tag|
      wf_entity_duplicated.tags << tag
    end
  end

  def update_taggable_index
    return unless %w[Graph Document].include?(taggable_type)

    begin
      taggable.__elasticsearch__.index_document
    rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
      ExceptionNotifyService.notify(e, "unavailable index")
    rescue Faraday::ConnectionFailed => e
      ExceptionNotifyService.notify(e, "unavailable faraday service")
    end
  end
end
