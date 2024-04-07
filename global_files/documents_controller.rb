# frozen_string_literal: true

class DocumentsController < ApplicationController
  include ListableWorkflow

  after_action :verify_policy_scoped, only: :index
  after_action :verify_authorized, except: %i[index favor unfavor favor_one
                                              unfavor_one unlock lock
                                              confirm_delete linkable
                                              confirm_move confirm_author author
                                              deactivate activate
                                              check_reference]

  before_action :require_document_in_accept_state, only: [:unlock]

  before_action :check_deactivation,
                only: %i[show show_properties interactions actors diary
                         historical]

  # TODO: Remove unused `count` parameter
  def wording(_count = 1)
    {
      # the document has not the required state to be accepted or rejected
      document_wrong_state: I18n.t("controllers.documents.errors.document_wrong_state"),

      # warns the user that the document is deactivated
      document_deactivated: I18n.t("controllers.documents.warning.document_deactivated")
    }
  end

  def new
    @document = Document.new
    authorize @document, :create?

    if params[:directory_id].present?
      directory = current_customer.root_directory.self_and_descendants.find(params[:directory_id])
      @document.directory = directory
    end

    if current_customer.max_graphs_and_docs_reached?
      @error_max_graphs_and_docs = I18n.t("errors.max_graphs_and_docs_reached")
    end

    respond_to do |format|
      format.html {}
      format.js {}
      format.json do
        @submit_format = "json"
        form_html = render_to_string(partial: "form_new", formats: [:html])
        render json: { form_new: form_html }
      end
    end
  end

  # TODO: Separate method into smaller private methods
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def create
    @document = current_customer.documents.new(document_params) do |document|
      document.directory ||= current_customer.root_directory
      document.author = current_user
      document.state = Document.states.first
    end

    begin
      authorize @document, :create?
    rescue StandardError
      @document.errors.add :base, :create_not_allowed
    end

    if @document.errors.empty? && @document.valid? && !current_customer.max_graphs_and_docs_reached? && @document.save
      DocumentsLog.create(document_id: @document.id, user_id: @document.author_id, action: "created", comment: nil)
      notify_owner_if_max_graphs_and_docs_approaching(@document)
      flash_x_success I18n.t("controllers.documents.successes.create")
      respond_to do |format|
        format.js { render :create }
        format.xml { render xml: @document }
        format.json { render json: @document.to_json(current_user: current_user) }
      end
    else
      if current_customer.max_graphs_and_docs_reached?
        @error_max_graphs_and_docs = I18n.t("errors.max_graphs_and_docs_reached")
      end
      fill_errors_hash(I18n.t("controllers.documents.errors.create")) if @document.errors.empty?
      respond_to do |format|
        format.js { render :new }
        format.xml { render xml: @document.errors.full_messages, status: 422 }
        if params[:renaissance]
          format.json do
            render json: { full_errors: @document.errors.full_messages, errors: @document.errors.messages }, status: 422
          end
        else
          format.json do
            @submit_format = "json"
            form_with_error = render_to_string(partial: "form_new", formats: [:html])
            render json: { form_new: form_with_error }, status: :unprocessable_entity
          end
        end
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def edit_actual_url
    @document = current_customer.documents.find(params[:id])
    authorize @document, :update?
  end

  def confirm_destroy_groupdocument
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :destroy_groupdocument?
  end

  def confirm_destroy_version
    @document = current_customer.documents.find(params[:id])
    authorize @document, :destroy_version?
  end

  def destroy_version
    @document = current_customer.documents.find(params[:id])
    authorize @document, :destroy_version?
    begin
      @document.destroy
      flash[:success] = I18n.t("controllers.documents.successes.delete_version")
      redirect_to documents_path
    rescue ActiveRecord::DeleteRestrictionError
      flash[:error] = I18n.t("controllers.documents.errors.delete_version")
      redirect_to show_properties_document_path(@document)
    end
  end

  def show
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :document_viewable?
    redirect_to show_properties_document_path(@document)
  end

  def show_properties
    @document = current_user.customer.documents.find(params[:id])
    @settings_print_footer = current_customer.settings.print_footer
    authorize @document, :document_viewable?
    respond_to do |format|
      format.html {}
      format.js {}
    end
  end

  def download
    @document = current_customer.documents.find(params[:id])

    authorize @document, :download?

    path = File.join(Settings.carrierwave.private_uploads_path, "document",
                     "file", @document.id.to_s, params[:file_name].to_s)

    raise ActiveRecord::RecordNotFound unless File.exist?(path)

    send_file(path)
  end

  def search_actors
    @document = current_customer.documents.find(params[:id])
    authorize @document, :document_viewable?
    query = params[:query]
    @users = User.search(query, current_user).records
    @users = current_customer.users_list false, true, @users
    @groups = Group.search(query, current_customer).records

    respond_to do |format|
      format.json do
        @items = @users + @groups
        render "actors"
      end
    end
  end

  def diary
    @document = current_customer.documents.find(params[:id])
    authorize @document, :document_viewable?
  end

  def historical
    @document = current_customer.documents.find(params[:id])
    authorize @document, :document_viewable?
  end

  def confirm_author
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :change_author?
  end

  def author
    @document = current_user.customer.documents.find(params[:id])
    if @document.change_author(current_user, params[:document][:author_id])
      flash[:success] = I18n.t("controllers.documents.author_changed")
    else
      flash[:error] = I18n.t("controllers.documents.errors.change_author")
    end
    redirect_to show_properties_document_path(@document)
  end

  def update
    @document = current_user.customer.documents.find(params[:id])
    begin
      authorize @document
    rescue StandardError
      @document.errors.add :base, I18n.t("controllers.graphs.error_update")
    end
    @document.update_attributes(document_params) unless @document.errors.any?

    # Hack to prevent HTTP 204 for print_footer which send an empty data response.
    if params[:document][:custom_print_footer].present?
      render json: { display_as: @document.custom_print_footer }
    else
      respond_with_bip(@document)
    end
  end

  def update_tags
    tags = JSON.parse params[:tags]
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :update_tags?

    @document.tags = tags.map do |tag|
      current_customer.tags.find_or_create_by(label: tag["text"])
    end

    @document.save
    @tags = @document.tags
    render "tags/update_tags"
  end

  # TODO: Use private method error handling with early return to simplify
  # rubocop:disable Metrics/AbcSize
  def update_actual_url
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :update?

    # Attention, il ne faut pas supprimer le file courant s'il est changé par un autre...
    @document.remove_file! unless params[:document][:url].empty?

    @document.url = nil
    logger.debug "--> @document : #{@document.inspect}"
    if @document.update_attributes(document_params)
      flash[:success] = I18n.t("controllers.documents.successes.update_actual_url")
      respond_to do |format|
        format.js {}
        format.html { redirect_to show_properties_document_path(@document) }
      end
    else
      i18nt = I18n.t("controllers.documents.errors.update_actual_url")
      fill_errors_hash(i18nt)
      flash[:error] = i18nt
      respond_to do |format|
        format.js { render :edit_actual_url }
        format.html { redirect_to show_properties_document_path(@document) }
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def move_document
    parent_directory = current_customer.directories.find(params[:parent_id])
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :move_document?
    @document.directory = parent_directory
    if @document.save
      flash[:success] = I18n.t("controllers.documents.successes.move_document")
    else
      fill_errors_hash I18n.t("controllers.documents.errors.move_document", title: @document.title)
      render :error_move_document
    end
  end

  def linkable
    return unless request.xhr?

    documents = Groupdocument.documents_linkable(current_customer)
    respond_to do |format|
      format.json { render json: { documents: documents.to_json } }
    end
  end

  # TODO: Simplify with private method I18n/flash error handling
  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def start_wf
    @document = current_customer.documents.find(params[:id])
    authorize @document, :update?

    if @document.documents_viewers.count.zero?
      return flash_x_error I18n.t("controllers.documents.error_viewers"), :method_not_allowed
    end

    if @document.publisher.nil?
      return flash_x_error I18n.t("controllers.documents.error_publisher"), :method_not_allowed
    end

    unless @document.in_edition? && (current_user.designer_of?(@document) || current_user.process_admin?)
      return flash_x_error I18n.t("controllers.documents.error_start_wf"), :forbidden
    end

    comment = unless current_user.designer_of?(@document)
                I18n.t("documents.states.new.admin_start_workflow", admin: current_user.name.full,
                                                                    user: @document.author.name.full)
              end
    DocumentsLog.create(document_id: @document.id, user_id: current_user.id, action: "wf_started", comment: comment)
    @document.next_state(current_user)
    flash_x_success I18n.t("controllers.documents.document_wf_started")
    respond_to do |format|
      format.js do
        @partial = "documents/states/#{wf_entity_state_to_partial(@document)}"
        render template: "documents/state_change"
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def confirm_increment_version
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :increment_version?
  end

  # TODO: Simplify by using a private method for error handling
  # rubocop:disable Metrics/AbcSize
  def increment_version
    Document.transaction do
      @document = current_user.customer.documents.find(params[:id])
      authorize @document, :increment_version?
      next_version = params[:next_version]
      if @document.increment_version(next_version)
        updated_document = Document.find(@document.id)
        DocumentsLog.create(document_id: updated_document.child.id, user_id: current_user.id, action: "created",
                            comment: nil)
        @document.reload
        flash[:success] = I18n.t("controllers.documents.document_version_incremented")
        redirect_to show_properties_document_path(@document.child)
      else
        flash[:error] = I18n.t("controllers.documents.error_increment_version")
        logger.debug "--> erreur d'incrémentation de version du document survenue."
        redirect_to show_properties_document_path(@document)
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def confirm_historical_increment_version
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :historical_increment_version?
  end

  # TODO: Simplify by using a private method for error handling
  # rubocop:disable Metrics/AbcSize
  def historical_increment_version
    Document.transaction do
      @document = current_user.customer.documents.find(params[:id])
      authorize @document, :historical_increment_version?
      next_version = params[:next_version]
      if @document.increment_version(next_version)
        next_versioned_document = @document.groupdocument.last_available
        DocumentsLog.create(document_id: next_versioned_document.id, user_id: current_user.id, action: "created",
                            comment: nil)
        flash[:success] = I18n.t("controllers.documents.document_version_incremented")
        redirect_to show_properties_document_path(next_versioned_document)
      else
        flash[:error] = I18n.t("controllers.documents.error_increment_version")
        redirect_to show_properties_document_path(@document)
      end
    end
  end
  # rubocop:enable Metrics/AbcSize

  def unlock
    @document = current_customer.documents.find params[:id]
    @document_unlocked = true
    flash_x_success I18n.t("controllers.documents.unlocked")
    location = "documents/states"
    respond_to do |format|
      format.js do
        @partial = if @document.in_edition?
                     "#{location}/new"
                   else
                     "#{location}/admin_#{wf_entity_state_to_partial(@document)}"
                   end
        render template: "documents/state_change"
      end
    end
  end

  def user_not_authorized
    flash[:error] = I18n.t("controllers.application.not_authorized")
    redirect_to documents_path
  end

  ##
  # Render the interactions html view of the document specified in `params[:id]`
  #
  # Interactions are:
  # - Graphs that contains a link to the current document.
  # - Improver events that impact this document.
  # - Improver acts that impact this document.
  # - Risks that affect this document.
  #
  def interactions
    @document = current_customer.documents.find params[:id]
    authorize @document, :document_viewable?
    @linked_graphs = @document.linked_graphs
    @events = @document.events.select do |event|
      Pundit.policy(current_user, event).show?
    end
    @acts = @document.acts.select do |act|
      Pundit.policy(current_user, act).show?
    end
    @risks = @document.risks.select do |risk|
      Pundit.policy(current_user, risk).show?
    end
  end

  def deactivate
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :deactivate?
    comment = params[:comment]
    current_user.toggle_entity_deactivation(@document, true, comment)
    respond_to do |format|
      format.js do
        @partial = "documents/states/#{wf_entity_state_to_partial(@document)}"
        render template: "documents/state_change"
      end
      format.html {}
    end
  end

  def activate
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :activate?
    comment = params[:comment]
    current_user.toggle_entity_deactivation(@document, false, comment)
    respond_to do |format|
      format.js do
        @partial = "documents/states/#{wf_entity_state_to_partial(@document)}"
        render template: "documents/state_change"
      end
      format.html {}
    end
  end

  def settings_print_footer
    @document = current_user.customer.documents.find(params[:id])
    authorize @document, :update?

    respond_to do |format|
      format.js {} if @document.update_attributes(print_footer: nil)
    end
  end

  def check_reference
    # here goes the reference uncity checking code
    reference = params[:reference]

    respond_to do |format|
      format.json do
        render json: {
          suggestions: current_customer.documents.includes(:groupdocument).order("groupdocuments.created_at desc")
                                       .pluck(:reference)
                                       .select { |ref| ref.downcase.start_with?(reference.downcase.strip) }.uniq
                                       .first(5)
        }
      end
    end
  end

  def read_confirmation
    @document = current_customer.documents.find(params[:id])
    authorize @document
    confirm_read = params[:document][:confirm_read]
    if confirm_read.present? && confirm_read.to_i == 1
      @document.read_confirmations.create(user: current_user)
      flash_x_success t(".success")
    else
      flash_x_error t(".error")
      head :internal_server_error
    end
  end

  def list_read_confirmations
    @document = current_customer.documents.find(params[:id])

    authorize(@document, :show_read_confirmations?)
  end

  def send_read_confirmation_reminders
    @document = current_customer.documents.find(params[:id])
    authorize @document

    @document.update_attribute("read_confirm_reminds_at", Time.now)

    @document.unconfirmed_viewers.each do |user|
      SendReadConfirmationReminderWorker.perform_async(current_user.id, user.id, @document.class.to_s, @document.id)
    end
    respond_to do |format|
      format.js do
        flash[:success] = t(".success")
        render js: "Turbolinks.visit('#{actors_document_path(@document)}')"
      end
    end
  end

  private

  def document_params
    params.require(:document).permit(:title, :reference, :version, :url, :file, :file_cache, :original_filename,
                                     :purpose, :domain, :confidential, :news, :directory_id, :custom_print_footer,
                                     :print_footer)
  end

  def fill_errors_hash(basic_msg)
    @errors = { warning: [basic_msg] }
    @document.errors.messages.each do |_, msg|
      msg.each do |one_msg|
        @errors[:warning] << one_msg
      end
    end
  end

  def require_document_in_accept_state
    @document = current_customer.documents.find(params[:id])

    flash_x_error wording[:document_wrong_state], :method_not_allowed unless document_unlockable?(@document)
  end

  def document_unlockable?(document)
    document.in_edition? || document.in_approval? || document.in_verification? ||
      document.in_publication? || document.in_scheduled_publication?
  end

  def index_orders_last_position
    { type: ->(documents) { documents.order("extension, title") } }
  end

  def check_deactivation
    @document = current_customer.documents.find(params[:id])

    flash.now[:warning] = wording[:document_deactivated] if @document.is_deactivated?
  end
end
