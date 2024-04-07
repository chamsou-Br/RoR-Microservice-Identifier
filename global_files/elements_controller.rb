# frozen_string_literal: true

class ElementsController < ApplicationController
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def index
    graph = current_user.customer.graphs.find(params[:graph_id])
    # elements = graph.elements
    # Ordering en mettant les roles d'abord pour la bonne construction du graph.
    elements_role = []
    elements_no_role = []
    graph.elements.each do |element|
      if element.is_role?
        elements_role << element
      else
        elements_no_role << element
      end
    end
    elements = elements_role + elements_no_role

    # Select settings colors as well
    colors_customer = []
    current_customer.settings.colors.active.all.each do |color_record|
      master_color = color_record.value.to_s
      slave_colors = []
      current_customer.settings.colors.shades_palette(color_record.value).each { |palette| slave_colors << palette.hex }
      colors_customer << { master_color: master_color, slave_colors: slave_colors }
    end
    # Etant au format json, la methode Element.as_json est appelée (elle include les pastilles)
    respond_to do |format|
      format.json do
        render json: {
          elements: elements,
          arrows: graph.arrows,
          lanes: graph.lanes,
          pastilles_customer: current_customer.settings.pastilles.where(activated: true),
          background: graph.background,
          colors_customer: colors_customer
        }
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
end
