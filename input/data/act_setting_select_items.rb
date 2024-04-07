# frozen_string_literal: true

class ActSettingSelectItems < ApplicationRecord
  belongs_to :act_setting, optional: true
end
