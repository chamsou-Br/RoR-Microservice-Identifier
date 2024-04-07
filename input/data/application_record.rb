# frozen_string_literal: true

class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  # @!attribute [r] id
  #   @return [Integer]
end
