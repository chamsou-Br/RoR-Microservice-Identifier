# frozen_string_literal: true

class GraphBackgroundsController < ApplicationController
  after_action :verify_authorized, except: %i[new show]

  # TODO: Move instance variable settings into private methods
  # rubocop:disable Metrics/AbcSize
  def new
    @graph = current_customer.graphs.find(params[:graph_id])
    @graph_background = @graph.background || GraphBackground.new

    @settings = current_customer.settings
    @colors = {}
    @settings.colors.active.all.each do |color_record|
      @colors[color_record.value.to_s] = @settings.colors.shades_palette(color_record.value).map(&:hex)
    end

    respond_to do |format|
      format.html {}
      format.js {}
      format.json do
        @submit_format = "json"
        render json: {
          form_new_image: render_to_string(partial: "graph_backgrounds/types/form_new_image", formats: [:html]),
          form_new_pattern: render_to_string(partial: "graph_backgrounds/types/form_new_pattern", formats: [:html]),
          form_new_color: render_to_string(partial: "graph_backgrounds/types/form_new_color", formats: [:html])
        }
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def show
    graph_image = GraphBackground.find(params[:id])
    image_version = params[:version] || "standard"

    file_path = case image_version
                when "standard" then graph_image.file_url.to_s
                when "show", "preview" then graph_image.file_url(image_version.to_sym).to_s
                end

    send_file("public#{file_path}", disposition: "inline", x_sendfile: true)
  end

  def create
    @graph = current_customer.graphs.find(params[:graph_id])
    authorize @graph, :background_image?

    @graph_background = GraphBackground.create!(file: params[:graph_background][:file], opacity: 100)

    respond_to do |format|
      format.json { render json: { graph_background: @graph_background } }
    end
  end
end
