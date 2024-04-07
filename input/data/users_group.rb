# frozen_string_literal: true

# == Schema Information
#
# Table name: users_groups
#
#  user_id  :integer
#  group_id :integer
#  id       :integer          not null, primary key
#
# Indexes
#
#  index_users_groups_on_group_id              (group_id)
#  index_users_groups_on_group_id_and_user_id  (group_id,user_id)
#  index_users_groups_on_user_id               (user_id)
#

class UsersGroup < ApplicationRecord
  belongs_to :user
  belongs_to :group
end
