# frozen_string_literal: true

# rubocop:disable all
class GraphsController < ApplicationController
  include TagsHelper
  include DirectoriesHelper
  include ListableWorkflow

  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: %i[index favor unfavor favor_one
                                              unfavor_one update_model_list
                                              update_model_preview
                                              graphs_linkable
                                              confirm_move unlock lock
                                              confirm_author author pilot
                                              generate_all_svg export_all
                                              deactivate activate check_reference]

  before_action :require_graph_in_accept_state,
                only: [:unlock]

  before_action :check_deactivation,
                only: %i[show show_properties interactions actors diary historical]

  # Flash messages sent back through the request using X headers
  def wording(_count = 1)
    {
      # the graph has not the required state to be accepted or rejected
      graph_wrong_state: I18n.t('controllers.graphs.errors.graph_wrong_state'),
      # warns the user that the graph is deactivated
      graph_deactivated: I18n.t('controllers.graphs.warning.graph_deactivated')
    }
  end

  def show
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :graph_viewable?

    respond_to do |format|
      format.json { render json: { properties: @graph.to_json } }
      format.html do
        if params.key?(:fs) && params[:fs]
          render partial: "show_fullscreen", layout: "application_fullscreen", locals: { title: @graph.title }
        else
          begin
            @contribution = Contribution.find(params[:contribution]) unless params[:contribution].blank?
          rescue ActiveRecord::RecordNotFound
            flash[:warning] = I18n.t("controllers.contributions.errors.not_found")
            redirect_to graph_path(@graph)
          end
        end
      end
    end
  end

  def show_properties
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :graph_viewable?
    respond_to do |format|
      format.html {}
    end
  end

  def new
    @graph = Graph.new
    authorize @graph, :create?

    unless params[:directory_id].blank?
      directory = current_customer.root_directory.self_and_descendants.find(params[:directory_id])
      @graph.directory = directory
    end

    @graph.type  = Graph.types.first
    @graph.level = 2
    @models = Model.where(type: @graph.type, level: @graph.level)
    @graph.model = @models.first if @models

    if current_customer.max_graphs_and_docs_reached?
      @error_max_graphs_and_docs = I18n.t('errors.max_graphs_and_docs_reached')
    end

    respond_to do |format|
      format.html {}
      format.js {}
      format.json do
        @levels = params[:level].is_a?(Array) ? params[:level] : [params[:level]]
        @submit_format = 'json'
        form_new_html = render_to_string(partial: 'form_new', formats: [:html])
        render json: { form_new: form_new_html }
      end
    end
  end

  def create
    # TODO: check if this is still possible. This line seems to be unreachable from the graph creation form.
    params[:graph][:tags] = consolidate(params[:graph][:tags]) unless params[:graph][:tags].nil?

    @graph = Graph.new(graph_params)
    @graph.state = Graph.states.first
    @graph.directory ||= current_customer.root_directory
    @graph.type ||= Graph.types.first
    @graph.customer = current_customer
    @graph.author = current_user

    begin
      authorize @graph, :create?
    rescue StandardError
      @graph.errors.add :title, :denied
    end

    if @graph.errors.empty? && @graph.valid? && !current_customer.max_graphs_and_docs_reached? && @graph.save
      GraphsLog.create(graph_id: @graph.id, user_id: @graph.author_id, action: "created", comment: nil)
      notify_owner_if_max_graphs_and_docs_approaching(@graph)
      flash[:success] = I18n.t('controllers.graphs.graph_created')
      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: @graph }
        format.js
      end
    else
      if current_customer.max_graphs_and_docs_reached?
        @graph.errors.add :title, I18n.t('errors.max_graphs_and_docs_reached')
      end
      fill_errors_hash(I18n.t('controllers.graphs.error_create'))
      respond_to do |format|
        format.html # show.html.erb
        format.json { render json: { full_errors: @graph.errors.full_messages, errors: @graph.errors.messages }, status: 422 }
        format.js   { render :error_create, status: :unprocessable_entity }
      end
    end
  end

  def update
    @graph = current_user.customer.graphs.find(params[:id])
    begin
      authorize @graph
    rescue StandardError
      @graph.errors.add :base, I18n.t('controllers.graphs.error_update')
    end

    # Edition du graph autorisé qu'en édition.
    if @graph.in_edition?
      respond_to do |format|
        if @graph.update_attributes(graph_params)
          format.html do
            flash[:success] = I18n.t('controllers.graphs.graph_updated')
          end
          # HACK: preventing HTTP 204 for print_footer which send an empty data response.
          if params[:graph][:custom_print_footer].present?
            format.json { render json: { display_as: @graph.custom_print_footer } }
          else
            format.json { respond_with_bip(@graph) }
          end
        else
          format.html do
            fill_errors_hash(I18n.t('controllers.graphs.error_update'))
            render :error_create
          end
          format.json { respond_with_bip(@graph) }
        end
      end
    else
      @graph.errors.add :base, :locked
      respond_to do |format|
        format.html do
          fill_errors_hash(I18n.t('controllers.graphs.error_update'))
          render :error_create
        end
        format.json do
          render json: format_for_bip(I18n.t('controllers.graphs.error_update')), status: :unprocessable_entity
        end
      end
    end
  end

  def draw
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :draw?
    render layout: 'editor'
  end

  def renaissance
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :renaissance?
    redirect_to(draw_graph_path(@graph)) && return if @graph.level != 2
    render layout: 'renaissance'
  end

  def distribute
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :draw?
    render layout: 'editor'
  end

  def generate_svg
    graph = current_customer.graphs.find(params[:id])
    authorize graph, :generate_svg?
    # on serialize le svg
    graph.svg = params[:svg]
    graph.save(touch: false)
    respond_to do |format|
      format.json do
        render json: { svg: graph.svg }
      end
    end
  end

  def generate_all_svg
    raise "not authorized" unless GraphPolicy.new(current_user, nil).generate_all_svg?
    raise 'wrong parameters' unless generate_all_svg_params.permitted?

    direction = params[:direction].blank? ? :desc : (params[:direction] == "first" ? :asc : :desc)
    except_ids = params[:except].blank? ? "" : params[:except].split(',').flatten

    if except_ids.blank?
      @graph = Graph.where(svg: nil, customer: current_customer).order(id: direction).take
      @nb_graphs_no_svg = Graph.where(svg: nil, customer: current_customer).count
    else
      @graph = Graph.where(svg: nil, customer: current_customer).where.not(id: except_ids).order(id: direction).take
      @nb_graphs_no_svg = Graph.where(svg: nil, customer: current_customer).where.not(id: except_ids).count
    end
    @graph&.update_attribute(:svg, "Processing...")

    # On prend la langue de l'author du graph, notamment pour les formes ET/OU
    I18n.locale = @graph.author.language if !@graph.nil? && !@graph.author.nil?
  end

  def svg
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :generate_svg?
    render partial: "svg_workbench"
  end

  def save
    logger.debug("starting save graph")

    if params[:elements].instance_of? String
      js_elements   =  JSON.parse params[:elements]
      js_arrows     =  JSON.parse params[:arrows]
      js_lanes      =  JSON.parse params[:lanes]
      js_graph      =  JSON.parse params[:graph]
      js_background =  JSON.parse params[:background]
    else
      logger.info "NOT A STRING"
      js_elements  =  params.permit![:elements]
      js_arrows    =  params.permit![:arrows]
      js_lanes     =  params.permit![:lanes]
      js_graph     =  params.permit![:graph]

      js_elements ||= []
      js_lanes ||= []
      js_arrows ||= []
      logger.info "js_lanes #{js_lanes.inspect}"
    end

    graph = current_user.customer.graphs.find(params[:id])
    old_linked_internal_roles = graph.linked_internal_roles
    if params[:mode] && params[:mode] == "generate_svg"
      authorize graph, :generate_svg?
    else
      authorize graph, :draw?
    end

    if bad_save_request?(params)
      handle_bad_save_request(graph,params)
      return
    end

    duplicate_role_elements = []
    element_id_mapping = {}

    Element.transaction do
      available_element_ids = js_elements.collect { |element| element["id"] }
      if available_element_ids.empty?
        graph.elements.destroy_all
      else
        graph.elements.where("id NOT IN (?)", available_element_ids).destroy_all
      end

      # Ordering elements
      js_roles = []
      js_other = []
      js_elements.each do |js_element|
        if js_element["shape"] == "role"
          js_roles << js_element
        else
          js_other << js_element
        end
      end
      js_elements = js_roles + js_other

      graph.filter_roles(js_roles)

      # Save each elements
      js_elements.each do |js_element|
        graph, _element, duplicate_role_elements, element_id_mapping = save_element(graph, js_elements, js_element, js_arrows, js_lanes, duplicate_role_elements, element_id_mapping)
      end

      # Lanes
      graph.lanes.delete_ids_not_in(js_lanes)
      js_lanes.each do |js_lane|
        graph.lanes.create_or_update_from_json(js_lane)
      end

      # Arrows
      graph.arrows.delete_ids_not_in(js_arrows)
      js_arrows.each do |js_arrow|
        arrow = graph.arrows.create_or_update_from_json(js_arrow)
        unless arrow.valid?
          logger.debug "arrow errors  : #{arrow.errors.messages}"
          graph.errors.add :base, I18n.t("controllers.graphs.error_update")

          # Add each arrow error in the `arrows` key so the front-end can know
          # that something went wrong specifically with an arrow in the graph
          arrow.errors.messages.values.map(&:first).each do |err|
            graph.errors.add :arrows, err
          end
        end
      end

      # Graph
      graph.comment_index_int = js_graph['comment_index_int'] unless js_graph['comment_index_int'].nil?

      # On supprime le svg
      graph.svg = nil

      if graph.errors.none?
        if graph.save
          # On set les steps ssi le flag est actived
          graph.graph_steps.create(set: params[:steps]) if current_user.customer.graph_steps?
        end
      end

      # Background
      if graph.errors.empty?
        if js_background["file"].nil? && js_background["pattern"].nil? && js_background["color"].nil?
          graph.update_attributes(background: nil) if graph.background.present?
        elsif !js_background["id"].is_a?(Numeric) # New Background
          loc_background = GraphBackground.new
          loc_background.set_type(js_background)
          graph.update_attributes(background: loc_background)
        elsif graph.background.nil? || js_background["id"] != graph.background.id # Update backgroud relation when a new picture is used
          graph.update_attributes(background: GraphBackground.find_by_id(js_background["id"]))
          graph.background.set_type(js_background)
        else
          graph.background.set_type(js_background)
        end
      end

      if graph.errors.any?
        logger.debug "ActiveRecord::Rollback engaged !"
        logger.debug "graph.errors.messages : #{graph.errors.messages}"
        raise ActiveRecord::Rollback
      end
    end

    elements = get_graph_elements(graph)

    respond_to do |format|
      if graph.errors.empty?
        # On recharge le graph à partir de la BDD
        graph.reload
        # Select settings colors as well
        colors_customer = get_customer_colors(current_customer)
        format.json do
          render json: {
            graph: graph.to_json,
            elements: elements.to_json,
            arrows: graph.arrows.to_json,
            lanes: graph.lanes.to_json,
            pastilles_customer: current_customer.settings.pastilles.where(activated: true).to_json,
            colors_customer: colors_customer.to_json,
            background: graph.background
          }
        end

        # automatically add the graph's role to viewers list here
        graph.add_role_element_to_viewer(old_linked_internal_roles)
      else
        format.json do
          render json: {
            graph: graph.to_json,
            elements: elements.to_json,
            arrows: graph.arrows.to_json,
            lanes: graph.lanes.to_json,
            duplicate_role_elements: duplicate_role_elements.to_json,
            errors: graph.errors.to_json,
            background: graph.background
          }
        end
      end
    end
  end

  def update_model_list
    @models = Model.find_all_by_type_and_level(params[:type], params[:level])
    respond_to do |format|
      format.js
    end
  end

  def update_model_preview
    @model = Model.find(params[:id])
    respond_to do |format|
      format.js
    end
  end

  def graphs_linkable
    return unless request.xhr?

    from_graph = current_customer.graphs.find(params[:graph_id])
    graphs = Groupgraph.graphs_linkable(from_graph, params[:type], params[:level])
    logger.debug "--->graphs::: #{graphs}"
    logger.debug "--->graphs COUNT ::: #{graphs.count}"
    if params[:include_docs]
      documents = Groupdocument.documents_linkable(current_customer)
      respond_to do |format|
        format.json { render json: { graphs: graphs.to_json, documents: documents.to_json } }
      end
    else
      respond_to do |format|
        format.json { render json: { graphs: graphs.to_json } }
      end
    end
  end

  # List all applicable G1P depending of the requested query on the title.
  # Actually used on the dashboard.
  # Todo: Put this in index action when ng list refactoring is done (ie concern Workflow).
  def graphs_list
    authorize Graph
    graphs = current_customer.graphs.where("title like :q", q: "%#{params[:q]}%").where(state: "applicable", level: 1, type: "process").order(:title)

    respond_to do |format|
      format.json do
        render json: graphs.to_json(only: %i[id title reference state])
      end
    end
  end

  def confirm_move; end

  # TODO: One can also move a graph from the directory listing, through the
  # move_directories method. There should not be 2 ways to do the same thing.
  def move_graph
    parent_directory = current_customer.directories.find(params[:parent_id])
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :move_graph?
    @graph.directory = parent_directory
    if @graph.save
      flash[:success] = I18n.t('controllers.graphs.graph_moved')
    else
      fill_errors_hash I18n.t('controllers.graphs.error_move', graph: @graph)
      render :error_move_graph
    end
  end

  def update_tags
    tags = JSON.parse params[:tags]
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :update_tags?
    records = []
    tags.each do |tag|
      tag_rec = current_customer.tags.find_or_create_by(label: tag["text"])
      records << tag_rec
    end
    @graph.tags = records
    @graph.save
    @tags = @graph.tags
    render 'tags/update_tags'
  end

  def deactivate
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :deactivate?
    comment = params[:comment]
    current_user.toggle_entity_deactivation(@graph, true, comment)
    respond_to do |format|
      format.js do
        @partial = "graphs/states/#{wf_entity_state_to_partial(@graph)}"
        render template: 'graphs/state_change'
      end
      format.html {}
    end
  end

  def activate
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :activate?
    comment = params[:comment]
    current_user.toggle_entity_deactivation(@graph, false, comment)
    respond_to do |format|
      format.js do
        @partial = "graphs/states/#{wf_entity_state_to_partial(@graph)}"
        render template: 'graphs/state_change'
      end
      format.html {}
    end
  end

  # Search mock
  def search_actors
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :graph_viewable?
    query = params[:query]
    @users = User.search(query, current_user).records
    @users = current_customer.users_list false, true, @users
    @groups = Group.search(query, current_customer).records

    respond_to do |format|
      format.json do
        @items = @users + @groups
        render 'actors'
      end
    end
  end

  def diary
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :graph_viewable?

    respond_to do |format|
      format.html {}
    end
  end

  def historical
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :graph_viewable?

    respond_to do |format|
      format.html {}
    end
  end

  ##
  # Render the interactions html view of the graph specified in `params[:id]`
  #
  # Interactions are:
  # - Parent graphs, if there are any
  # - Children graphs, if there are any
  # - Elements that are used in the graph, like resources and documents.
  # - Improver events that impact this graph
  # - Risks that affect this graph
  #
  def interactions
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :graph_viewable?
    @interactions = {
      parents_actions: @graph.parent_graphs.select do |parent|
        Pundit.policy(current_user, parent).viewable?
      end,
      children_actions: @graph.child_graphs.select do |child|
        Pundit.policy(current_user, child).viewable?
      end,
      roles: @graph.linked_roles,
      documents_elmnts: @graph.documents_elmnts,
      resources_elmnts: @graph.resources_elmnts,
      inputs_elmnts: @graph.inputs_elmnts,
      outputs_elmnts: @graph.outputs_elmnts,
      arrow_inputs_main_process: @graph.arrow_inputs_main_process,
      arrow_outputs_main_process: @graph.arrow_outputs_main_process,
      events: @graph.events.select do |event|
        Pundit.policy(current_user, event).show?
      end,
      acts: @graph.acts.select do |act|
        Pundit.policy(current_user, act).show?
      end,
      risks: @graph.risks.select do |risk|
        Pundit.policy(current_user, risk).show?
      end
    }

    respond_to do |format|
      format.html {}
    end
  end

  def start_wf
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :update?
    if @graph.graphs_viewers.count == 0
      flash_x_error I18n.t('controllers.graphs.error_viewers'), :method_not_allowed
    elsif @graph.publisher.nil?
      flash_x_error I18n.t('controllers.graphs.error_publisher'), :method_not_allowed
    elsif @graph.in_edition? && (current_user.designer_of?(@graph) || current_user.process_admin?)
      comment = current_user.designer_of?(@graph) ? nil : I18n.t('graphs.states.new.admin_start_workflow', admin: current_user.name.full, user: @graph.author.name.full)
      GraphsLog.create(graph_id: @graph.id, user_id: current_user.id, action: "wf_started", comment: comment)
      @graph.next_state(current_user)
      flash_x_success I18n.t('controllers.graphs.graph_wf_started')
      respond_to do |format|
        format.js do
          @partial = "graphs/states/#{wf_entity_state_to_partial(@graph)}"
          render template: 'graphs/state_change'
        end
      end
    else
      flash_x_error I18n.t('controllers.graphs.error_start_wf'), :forbidden
    end
  end

  # DEVELOPMENT ONLY
  def reset
    @graph = current_customer.graphs.find(params[:id])
    Graph.where(@graph.id).update_all(state: 'new')
    GraphsViewer.where(@graph.id).delete_all
    GraphsVerifier.where(@graph.id).delete_all
    GraphsApprover.where(@graph.id).delete_all
    GraphPublisher.where(@graph.id).delete_all
    GraphsLog.where(@graph.id).delete_all
    @graph.reload
    respond_to do |format|
      format.js do
        @partial = "graphs/states/#{wf_entity_state_to_partial(@graph)}"
        render template: 'graphs/state_change'
      end
    end
  end

  def confirm_duplicate
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :duplicate?
    if current_customer.max_graphs_and_docs_reached?
      @error_max_graphs_and_docs = I18n.t('errors.max_graphs_and_docs_reached')
    end
  end

  def confirm_increment_version
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :increment_version?
  end

  def increment_version
    Graph.transaction do
      @graph = current_user.customer.graphs.find(params[:id])
      authorize @graph, :increment_version?
      next_version = params[:next_version]
      if @graph.increment_version(next_version)
        updated_graph = Graph.find(@graph.id)
        GraphsLog.create(graph_id: updated_graph.child.id, user_id: current_user.id, action: "created", comment: nil)
        @graph.reload
        flash[:success] = I18n.t('controllers.graphs.graph_version_incremented')
        redirect_to graph_path(@graph.child)
      else
        flash[:error] = I18n.t('controllers.graphs.error_increment_version')
        redirect_to graph_path(@graph)
      end
    end
  end

  def confirm_historical_increment_version
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :historical_increment_version?
  end

  def historical_increment_version
    Graph.transaction do
      @graph = current_user.customer.graphs.find(params[:id])
      authorize @graph, :historical_increment_version?
      next_version = params[:next_version]
      if @graph.increment_version(next_version)
        next_versioned_graph = @graph.groupgraph.last_available
        GraphsLog.create(graph_id: next_versioned_graph.id, user_id: current_user.id, action: "created", comment: nil)
        flash[:success] = I18n.t('controllers.graphs.graph_version_incremented')
        redirect_to graph_path(next_versioned_graph)
      else
        flash[:error] = I18n.t('controllers.graphs.error_increment_version')
        redirect_to graph_path(@graph)
      end
    end
  end

  def duplicate
    Graph.transaction do
      initial_graph = current_user.customer.graphs.find(params[:id])
      authorize initial_graph, :duplicate?
      if !current_customer.max_graphs_and_docs_reached?
        @graph = initial_graph.duplicate(graph_params, current_user)
        if @graph.errors.any?
          fill_errors_hash(I18n.t('controllers.graphs.error_duplicate'))
          render :error_create
        else
          notify_owner_if_max_graphs_and_docs_approaching(@graph)
          flash[:success] = I18n.t('controllers.graphs.graph_duplicated')
        end
      else
        @graph = initial_graph
        @graph.errors.add :base, I18n.t('errors.max_graphs_and_docs_reached')
        render :error_create
      end
    end
  end

  def confirm_delete
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :delete?
  end

  def confirm_delete_version
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :delete_version?
  end

  def delete_version
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :delete_version?
    begin
      @graph.destroy
      flash[:success] = I18n.t('controllers.graphs.successes.delete_version')
      redirect_to graphs_path
    rescue ActiveRecord::DeleteRestrictionError
      flash[:error] = I18n.t('controllers.graphs.errors.delete_version')
      redirect_to show_properties_graph_path(@graph)
    end
  end

  def unlock
    @graph = current_customer.graphs.find params[:id]
    @graph_unlocked = true
    flash_x_success I18n.t('controllers.graphs.unlocked')
    location = "graphs/states"
    respond_to do |format|
      format.js do
        @partial = @graph.in_edition? ? "#{location}/new" : "#{location}/admin_#{wf_entity_state_to_partial(@graph)}"
        render template: 'graphs/state_change'
      end
    end
  end

  def lock
    @graph = current_customer.graphs.find params[:id]
    @graph_unlocked = false
    flash_x_success I18n.t('controllers.graphs.locked')
    respond_to do |format|
      format.js do
        @partial = "graphs/states/#{wf_entity_state_to_partial(@graph)}"
        render template: 'graphs/state_change'
      end
    end
  end

  def confirm_author
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :change_author?
  end

  def confirm_pilot
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :change_pilot?
  end

  def author
    @graph = current_user.customer.graphs.find(params[:id])
    if @graph.change_author(current_user, params[:graph][:author_id])
      flash[:success] = I18n.t('controllers.graphs.author_changed')
    else
      flash[:error] = I18n.t('controllers.graphs.errors.change_author')
    end
    redirect_to show_properties_graph_path(@graph)
  end

  def pilot
    logger.debug "--> pilot params #{params.inspect}"
    @graph = current_user.customer.graphs.find(params[:id])
    if @graph.change_pilot(current_user, params[:graph][:pilot_id])
      flash[:success] = I18n.t('controllers.graphs.pilot_changed')
    else
      flash[:error] = I18n.t('controllers.graphs.errors.change_pilot')
    end
    redirect_to show_properties_graph_path(@graph)
  end

  def update_root
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :rootable?

    flash[:success] = I18n.t('controllers.graphs.root_graph_updated') if @graph.set_root(params[:graph][:root])
    respond_to do |format|
      format.js {}
    end
  end

  #
  # Clears the custom graph footer in favor of the customer-wide footer if the
  # user is authorized to update the graph.
  #
  # @return [void]
  #
  def settings_print_footer
    @graph = current_user.customer.graphs.find(params[:id])
    authorize @graph, :update?

    respond_to do |format|
      format.js {} if @graph.update_attributes(print_footer: nil)
    end
  end

  def check_reference
    # here goes the reference uncity checking code
    reference = params[:reference]

    respond_to do |format|
      format.json do
        render json: {
          suggestions: current_customer.graphs.includes(:groupgraph)
                                       .order('groupgraphs.created_at desc')
                                       .pluck(:reference)
                                       .select { |ref| ref.downcase.start_with?(reference.downcase.strip) }
                                       .uniq.first(5)
        }
      end
    end
  end

  def read_confirmation
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph

    confirm_read = params[:graph][:confirm_read]

    if confirm_read.present? && confirm_read.to_i == 1
      @graph.read_confirmations.create(user: current_user)
      flash_x_success t(".success")
    else
      flash_x_error t(".error")
      head :internal_server_error
    end
  end

  def list_read_confirmations
    @graph = current_customer.graphs.find(params[:id])

    authorize(@graph, :show_read_confirmations?)
  end

  def toggle_auto_role_viewer
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :toggle_auto_role_viewer?

    @flag = !@graph.groupgraph.auto_role_viewer
    @graph.toggle_auto_role_viewer(@flag)
    if @graph.errors.empty?
      flash_x_success t("controllers.graphs.successes.toggle_auto_role_viewer")
    else
      flash_x_error t("controllers.graphs.errors.toggle_auto_role_viewer")
    end

    respond_to do |format|
      format.js {}
    end
  end

  def toggle_review
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :toggle_review?

    @flag = !@graph.groupgraph.review_enable

    if @graph.toggle_review(@flag)
      flash_x_success I18n.t("controllers.graphs.successes.toggle_review.#{@flag}")
    else
      flash_x_error I18n.t("controllers.graphs.errors.toggle_review"), :method_not_allowed
    end

    respond_to do |format|
      format.json do
        render json: {
          value: @graph.groupgraph.review_enable,
          review_date: ->(g) { g.review_date.nil? ? '' : I18n.l(g.review_date) }.call(@graph.groupgraph),
          review_reminder: Groupgraph.review_reminders[@graph.groupgraph.review_reminder]
        }
      end
    end
  end

  def update_review_date
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :update_review_date?

    review_date = params[:review_date]

    if @graph.groupgraph.update(review_date: review_date)
      flash_x_success I18n.t("controllers.graphs.successes.update_review_date")
      head :ok
    else
      flash_x_error("#{I18n.t('controllers.graphs.errors.update_review_date')}" \
                    " : #{@graph.groupgraph.errors.full_messages.join('')}")
      @graph.reload
      render json: { value: I18n.l(@graph.groupgraph.review_date) }, status: :unprocessable_entity
    end
  end

  def update_review_reminder
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :update_review_reminder?

    review_reminder = params[:review_reminder].to_i
    Graph.transaction do
      @graph.groupgraph.review_reminder = review_reminder
      if @graph.groupgraph.save
        flash_x_success I18n.t("controllers.graphs.successes.update_review_reminder")
        head :ok
      else
        flash_x_error I18n.t("controllers.graphs.errors.update_review_reminder"), :unprocessable_entity
      end
    rescue ArgumentError
      flash_x_error I18n.t("controllers.graphs.errors.update_review_reminder"), :unprocessable_entity
      raise ActiveRecord::Rollback
    end
  end

  def complete_review
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph, :complete_review?

    if @graph.complete_review(current_user)
      flash_x_success I18n.t("controllers.graphs.successes.complete_review")
    else
      flash_x_error I18n.t("controllers.graphs.successes.complete_review"), :unprocessable_entity
    end
  end

  def steps
    graph = current_user.customer.graphs.find(params[:id])
    authorize graph, :steps?
    respond_to do |format|
      format.json do
        render json: {
          steps: graph.steps
        }
      end
    end
  end

  def reset_svg
    graph = current_customer.graphs.find(params[:id])
    authorize graph, :reset_svg?

    graph.svg = nil
    # `touch: false` so `updated_at` is unchanged and the graph does not appear updated.
    graph.save(touch: false)
    head :ok, content_type: "text/html"
  end

  def generate_all_svg_params
    valid = (params.keys.to_a - %w[controller action direction except]).empty?

    valid &= params['direction'] =~ /first|last/ if params.include?('direction')

    valid &= isParamAsArrayOfInteger?('except')
    params.permit! if valid
    params
  end

  def send_read_confirmation_reminders
    @graph = current_customer.graphs.find(params[:id])
    authorize @graph

    @graph.update_attribute("read_confirm_reminds_at", Time.now)

    @graph.unconfirmed_viewers.each do |user|
      SendReadConfirmationReminderWorker.perform_async(current_user.id, user.id, @graph.class.to_s, @graph.id)
    end
    respond_to do |format|
      format.js do
        flash[:success] = t(".success")
        render js: "Turbolinks.visit('#{actors_graph_path(@graph)}')"
      end
    end
  end

  private

  #
  # Returns `true` if the given `params` indicate a request from a badly
  # behaving front-end to nullify a graph.
  #
  def bad_save_request?(params)
    return if params[:mode] != "edit"
    return if params[:elements] != "[]"
    return if params[:arrows] != "[]"
    return if params[:lanes] != "[]"
    return if params[:steps] != "[]"
    return if params[:background] != "{}"

    true
  end

  #
  # Returns the array of `graph.elements` sorted by roles first.
  #
  def get_graph_elements(graph)
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

    elements_role + elements_no_role
  end

  #
  # Returns an array of `{ master_color: String, slave_colors: Array<String> }` from
  # the given `customer`'s colors, the semantics of which are undocumented but
  # is consumed this way by the front-end.
  #
  def get_customer_colors(customer)
    colors_customer = []

    customer.settings.colors.active.all.each do |color_record|
      master_color = color_record.value.to_s
      slave_colors = []

      current_customer.settings.colors.shades_palette(color_record.value).each do
        |palette| slave_colors << palette.hex
      end

      colors_customer << { master_color: master_color, slave_colors: slave_colors }
    end

    colors_customer
  end

  #
  # Notifies the "bugs" channel of a bad graph save request for the given
  # `graph` if the ENV defines an exception notifier webhook. Includes the
  # given `params` in the notification. Renders JSON as if the Graph was saved
  # unmodified so as not to break any front-end expectations.
  #
  def handle_bad_save_request(graph, params)
      mattermost_webhook = ENV.fetch("EXCEPTION_MATTERMOST_WEBHOOK", "")

      if mattermost_webhook.present?
        message = "Bad save recevied for graph `#{graph.id}``, " +
                  "customer `#{graph.customer.url}`, " +
                  "params `#{params.to_json}``"

        notifier = Slack::Notifier.new mattermost_webhook do
          defaults channel: "bugs"
        end

        notifier.ping message
      end

      elements = get_graph_elements(graph)
      colors_customer = get_customer_colors(current_customer)

      render json: {
        graph: graph.to_json,
        elements: elements.to_json,
        arrows: graph.arrows.to_json,
        lanes: graph.lanes.to_json,
        pastilles_customer: current_customer.settings.pastilles.where(activated: true).to_json,
        colors_customer: colors_customer.to_json,
        background: graph.background
      }
  end

  def graph_params
    params.require(:graph).permit(:type, :level, :level_and_tree, :title,
                                  :reference, :version, :domain, :purpose,
                                  :news, :confidential, :directory_id,
                                  :custom_print_footer, :print_footer)
  end

  def update_arrows_from_to(arrows, old_id, new_id)
    arrows.each do |arrow|
      if arrow["from"] == old_id
        arrow["from"] = new_id
      elsif arrow["to"] == old_id
        arrow["to"] = new_id
      end
    end
  end

  def update_lanes_from_to(lanes, old_id, new_id)
    lanes.each do |lane|
      # logger.debug "--> check for update lane #{lane} ; looking for old_id = #{old_id} "
      if lane["element_id"] == old_id
        # logger.debug "--> changing old element_id value (#{old_id}) to #{new_id}"
        lane["element_id"] = new_id
      end
    end
    # logger.debug "--> end of update_lanes_from_to : #{lanes}"
  end

  def update_pastilles_from_to(elements, old_id, new_id)
    elements.each do |element|
      next unless element["shape"] == "collaborative-instruction"

      element["pastilles"] ||= []
      element["pastilles"].each do |pastille|
        # logger.debug "--> check for update pastille #{pastille} ; looking for old_id = #{old_id} "
        if pastille["role_id"] == old_id
          # logger.debug "--> changing old role_id value (#{old_id}) to #{new_id}"
          pastille["role_id"] = new_id
        end
      end
    end

    # logger.debug "--> end of update_pastilles_from_to : #{elements}"
  end

  # TODO: Reduce parameters number.
  def save_element(graph, js_elements, js_element, js_arrows, js_lanes, duplicate_role_elements, element_id_mapping)
    # Il faut enlever les pastilles du js_element et les gérer à part
    js_pastilles = js_element["pastilles"] if js_element.include?("pastilles")
    js_element.delete_if { |key, _value| key == "pastilles" }

    if js_element["id"].is_a?(Numeric)
      if js_element.include?("container_id")
        js_element["parent_id"] = js_element["container_id"]
        js_element.delete_if { |key, _value| key == "container_id" }
      end

      element = graph.elements.find_or_create_by(id: js_element["id"])
      element.update_attributes(js_element)

    else
      # logger.debug("Non Numeric")
      js_element_id = js_element["id"]
      js_element.delete_if { |key, _value| key == "id" }

      if js_element.include?("container_id")
        if graph.elements.exists?(js_element["container_id"])
          js_element["parent_id"] = js_element["container_id"]
        else
          # First, save the container
          select_element = js_elements.select { |a_element| !a_element["id"].nil? && (a_element["id"] == js_element["container_id"]) }.first
          unless select_element.nil?
            js_elements.delete(select_element)
            graph, _select_element, duplicate_role_elements, element_id_mapping = save_element(graph, js_elements, select_element, js_arrows, js_lanes, duplicate_role_elements, element_id_mapping)
          end

          js_element["parent_id"] = element_id_mapping[js_element["container_id"]]
        end
        js_element.delete_if { |key, _value| key == "container_id" }
      end
      element = graph.elements.create(js_element)
      element_id_mapping[js_element_id] = element.id

      update_arrows_from_to(js_arrows, js_element_id, element.id)
      update_lanes_from_to(js_lanes, js_element_id, element.id)
      update_pastilles_from_to(js_elements, js_element_id, element.id) if element.shape == "role"

      # Handling parent_role affectation.
      select_elements = js_elements.select { |a_element| a_element["parent_role"] == js_element_id }
      select_elements.map { |elem| elem["parent_role"] = element.id } unless select_elements.none?

      # Handling leasher_id affectation.
      select_elements = js_elements.select { |a_element| a_element["leasher_id"] == js_element_id }
      select_elements.map { |elem| elem["leasher_id"] = element.id } unless select_elements.none?
    end

    # Gestion des pastilles pour le cas des collaborative-instructions
    if js_element["shape"] == "collaborative-instruction" && !js_pastilles.nil?
      element_id = if js_element["id"].is_a?(Numeric)
                     js_element["id"]
                   else
                     element.id
                   end

      js_pastille_ids = []
      js_pastilles.each do |js_pastille|
        js_pastille["element_id"] = element_id
        if js_pastille.include?("responsability")
          js_pastille["pastille_setting_id"] = js_pastille["responsability"]
          js_pastille.delete_if { |key, _value| key == "responsability" }
        end

        pastille = Pastille.create_or_update_from_json(js_pastille)
        graph.errors.add :base, :record_pastille unless pastille.valid?
        js_pastille_ids << pastille.id
      end
      # Suppression des pastilles en trop en BDD
      element.pastilles.each do |pastille|
        pastille.destroy unless js_pastille_ids.include?(pastille.id)
      end
    end
    graph, element, duplicate_role_elements = validate_element(graph, element, duplicate_role_elements)

    # Handling special case of 2 creation of the same new role.
    if element.shape == "role" || element.shape == "relatedRole"
      select_elements = js_elements.select do |a_element|
        (a_element["shape"] == "role" || a_element["shape"] == "relatedRole") &&
          a_element["text"] == element.text
      end
      unless select_elements.none?
        select_elements.map do |elem|
          elem["model_id"] = element.model_id, elem["model_type"] = element.model_type
        end
      end
    end

    [graph, element, duplicate_role_elements, element_id_mapping]
  end

  def validate_element(graph, element, duplicate_role_elements)
    if element.valid?
      if element.model_type == "Groupgraph" || element.model_type == "Groupdocument"
        begin
          element.model_type.constantize.find(element.model_id)
        rescue ActiveRecord::RecordNotFound
          ## set the model_type and model_id to nil
          element.model_type = nil
          element.model_id = nil
          element.title_color = "#000000"
          element.italic = false
        end
      end

      if element.shape == "role" || element.shape == "relatedRole"
        # Linkage automatique à l'entité si possible
        if element.model_id.blank?
          role = current_customer.roles.where(title: element.text, type: element.type).first
          # Si on ne le trouve pas, on créé l'entité
          if role.nil?
            role = current_customer.roles.create(
              title: element.text,
              type: element.type,
              author_id: current_user.id,
              writer_id: current_user.id)
          end

          if role.valid?
            element.model_id = role.id
            element.model_type = "Role"
            element.italic = true
          end
        else
          role = current_customer.roles.find(element.model_id)
        end

        if role.is_deactivated?
          graph.errors.add :base, :deactivated_role, {name: role.title}
        end

        graph.roles << role if !role.nil? && role.valid?

      elsif element.shape == "resource" && !element.model_id.blank?
        resource = current_customer.resources.find(element.model_id)
        if resource.is_deactivated?
          graph.errors.add :base, :deactivated_resource, {name: resource.title}
        end
      end
    end

    if (role.nil? || !role.valid?) && element.shape == "role"
      duplicate_role_elements << element
      if !role.nil? && role.id.blank?
        # Role name already taken
        graph.errors.add :existing_roles, ''
      else
        # Duplicated role name
        graph.errors.add :duplicated_roles_name, ''
      end
    elsif (role.nil? || !role.valid?) && element.shape == "relatedRole"
      graph.errors.add :base, I18n.t('controllers.graphs.validate_element.error_element_record',
        text: element.text)
      duplicate_role_elements << element
      graph.errors.add :text, I18n.t('controllers.graphs.validate_element.error_element_record',
        text: element.text)
    elsif !element.save
      graph.errors.add :base, I18n.t('controllers.graphs.validate_element.error_element_record',
        text: element.text)
      logger.debug "Error during element save------------> #{element.errors.messages}"
      if element.errors.messages[:text]
        duplicate_role_elements << element
        graph.errors.add :text, I18n.t('controllers.graphs.validate_element.error_element_record',
          text: element.text)
      end
    end

    [graph, element, duplicate_role_elements]
  end

  def fill_errors_hash(basic_msg)
    @errors = { warning: [basic_msg] }
    @graph.errors.messages.each do |_key, msg|
      msg.each do |one_msg|
        @errors[:warning] << one_msg
      end
    end
  end

  def require_graph_in_accept_state
    @graph = current_customer.graphs.find(params[:id])

    flash_x_error wording[:graph_wrong_state], :method_not_allowed unless graph_unlockable?(@graph)
  end

  def check_deactivation
    @graph = current_customer.graphs.find(params[:id])
    flash.now[:warning] = wording[:graph_deactivated] if @graph.is_deactivated?
  end

  def graph_unlockable?(graph)
    graph.in_edition? || graph.in_approval? || graph.in_verification? || graph.in_publication? || graph.in_scheduled_publication?
  end

  def index_orders
    { level: ->(graphs) { graphs.order('level, title') } }
  end
end
# rubocop:enable all
