# frozen_string_literal: true

# == Schema Information
#
# Table name: roles_users
#
#  id         :integer          not null, primary key
#  role_id    :integer
#  user_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#
# Indexes
#
#  index_roles_users_on_role_id              (role_id)
#  index_roles_users_on_role_id_and_user_id  (role_id,user_id)
#  index_roles_users_on_user_id              (user_id)
#

class RolesUser < ApplicationRecord
  belongs_to :role
  belongs_to :user
end
