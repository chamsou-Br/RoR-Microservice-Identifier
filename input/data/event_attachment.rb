# frozen_string_literal: true

# == Schema Information
#
# Table name: event_attachments
#
#  id         :integer          not null, primary key
#  event_id   :integer
#  title      :string(255)
#  file       :string(255)
#  author_id  :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_event_attachments_on_author_id  (author_id)
#  index_event_attachments_on_event_id   (event_id)
#

class EventAttachment < ApplicationRecord
  include MediaFile
  include LinkableFieldable

  belongs_to :event, optional: true
  belongs_to :author,
             foreign_key: "author_id", class_name: "User", optional: true

  # TODO: there is a serializer already at app/serializers/
  # Need to do a manual serialiazer as other parts (ElasticSearch)
  # count on the default as_json method, so it cannot be overwritten.
  def serialize_this
    as_json(only: %i[id title file])
  end
end
