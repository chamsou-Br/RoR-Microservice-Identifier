# frozen_string_literal: true

# == Schema Information
#
# Table name: audit_themes
#
#  id       :integer          not null, primary key
#  audit_id :integer
#  theme_id :integer
#
# Indexes
#
#  index_audit_themes_on_audit_id  (audit_id)
#  index_audit_themes_on_theme_id  (theme_id)
#

class AuditTheme < ApplicationRecord
  belongs_to :audit
  belongs_to :theme, class_name: "AuditThemeSetting"
end
