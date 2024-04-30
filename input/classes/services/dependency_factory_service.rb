# frozen_string_literal: true

# this class is responsible for creating all necessary models
# required for a Customer record to work properly
class DependencyFactoryService
  def self.create!(customer)
    ActiveRecord::Base.transaction do
      customer.save!

      customer.add_flag
      customer.add_customer_settings
      customer.create_root_directory
      customer.add_models

      settings = customer.settings
      settings.add_colors
      settings.add_default_nickname
      settings.add_pastilles
    end

    customer
  end
end
