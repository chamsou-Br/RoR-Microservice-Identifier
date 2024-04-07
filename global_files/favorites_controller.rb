# frozen_string_literal: true

class FavoritesController < ApplicationController
  def index
    @graphs = current_user.graphs_favored.order("type, level, title")
    @documents = current_user.documents_favored.order("title")
  end
end
