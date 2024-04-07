# frozen_string_literal: true

# rubocop: disable all
class GroupgraphsController < ApplicationController
  include ImproverNotifications

  def show
    # Le show retourne par défaut la version applicable si elle existe,
    # sinon, la last_available
    @graph = current_customer.groupgraphs.find(params[:id]).applicable_version_or_last_available
    if params.has_key?(:fs) && params[:fs]
      redirect_to graph_path(@graph, :fs => params[:fs])
    else
      redirect_to graph_path(@graph)
    end
  end

  def properties
    @graph = current_customer.groupgraphs.find(params[:id]).last_available
    respond_to do |format|
      format.json { render :json => {:properties => @graph.to_json }  }
      format.html { }
    end
  end

  def draw
    @graph = current_customer.groupgraphs.find(params[:id]).last_available
    if @graph.in_edition?
      redirect_to draw_graph_path(@graph)
    else
      flash[:error] = I18n.t('controllers.groupgraphs.errors.draw')
      redirect_to graph_path(@graph)
    end
  end

  def renaissance
    @graph = current_customer.groupgraphs.find(params[:id]).last_available
    if @graph.in_edition?
      redirect_to renaissance_graph_path(@graph)
    else
      flash[:error] = I18n.t('controllers.groupgraphs.errors.renaissance')
      redirect_to graph_path(@graph)
    end
  end

  def destroy
    @graph = current_customer.groupgraphs.find(params[:id]).last_available
    authorize @graph, :delete?
    events = @graph.groupgraph.graphs.to_a.sum { |g| g.events }.uniq
    if @graph.groupgraph.destroy
      if events.any?
        events.each do |event|
          log_action(event, current_user, "update")
        end
      end
      flash[:success] = I18n.t('controllers.groupgraphs.successes.destroy')
      redirect_to graphs_path
    else
      flash[:error] = I18n.t('controllers.groupgraphs.errors.destroy')
      redirect_to graph_path(@graph)
    end
  end

  def update
    groupgraph=Groupgraph.find(params[:id])
    graph=groupgraph.last_available
    authorize graph, :update?

    groupgraph.update_attributes(groupgraph_params)
    logger.info("Groupgraph #{groupgraph} updating...")
    flash_x_success I18n.t('controllers.groupgraphs.successes.updated')
    respond_to do |format|
      format.json {
        respond_with_bip(groupgraph)
      }
    end
  end

  ###
  # PRIVATE
  ###
  private

  def groupgraph_params
    params.require(:groupgraph).permit(:review_enable, :review_date, :review_reminder)
  end
end
# rubocop: enable all
