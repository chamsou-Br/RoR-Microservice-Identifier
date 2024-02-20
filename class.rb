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
  end
end
