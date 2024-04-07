# frozen_string_literal: true

# == Schema Information
#
# Table name: event_domains
#
#  id        :integer          not null, primary key
#  event_id  :integer
#  domain_id :integer
#
# Indexes
#
#  index_event_domains_on_domain_id               (domain_id)
#  index_event_domains_on_domain_id_and_event_id  (domain_id,event_id)
#  index_event_domains_on_event_id                (event_id)
#

class EventDomain < ApplicationRecord
  belongs_to :event
  belongs_to :domain, class_name: "EventDomainSetting"
end
