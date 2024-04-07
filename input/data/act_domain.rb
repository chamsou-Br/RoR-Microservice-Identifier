# frozen_string_literal: true

# == Schema Information
#
# Table name: act_domains
#
#  id        :integer          not null, primary key
#  act_id    :integer
#  domain_id :integer
#
# Indexes
#
#  index_act_domains_on_act_id                (act_id)
#  index_act_domains_on_act_id_and_domain_id  (act_id,domain_id)
#  index_act_domains_on_domain_id             (domain_id)
#

class ActDomain < ApplicationRecord
  belongs_to :act
  belongs_to :domain, class_name: "ActDomainSetting"
end
