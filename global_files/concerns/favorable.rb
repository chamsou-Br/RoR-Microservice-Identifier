# frozen_string_literal: true

module Favorable
  extend ActiveSupport::Concern

  # Route: post 'favor'
  def favor
    item = extract_selection[:items].first
    association = item[:class].pluralize

    record = find_association(association, item)

    head :ok if current_user.send("#{association}_favored").push(record)
  end

  # Route: post 'unfavor'
  def unfavor
    item = extract_selection[:items].first
    association = item[:class].pluralize

    record = find_association(association, item)

    head :ok if current_user.send("#{association}_favored").destroy(record)
  end

  # Route: post 'favor_one'
  def favor_one
    association = controller_name

    @record = find_association(controller_name, params)

    render "shared/favor/favor" if current_user.send("#{association}_favored").push(@record)
  end

  # Route: post 'unfavor_one'
  def unfavor_one
    association = controller_name

    @record = find_association(association, params)

    render "shared/favor/unfavor" if current_user.send("#{association}_favored").destroy(@record)
  end

  private

  def find_association(association, item)
    raise "method_not_allowed" unless Favorite.association_favorisable?(association)

    case association
    when "graphs", "directories", "resources", "roles", "documents"
      current_customer.send(association).find(item[:id])
    when "process_notifications", "new_notifications"
      current_user.send(association).find(item[:id])
    end
  end
end
