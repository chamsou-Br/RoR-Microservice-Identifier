# frozen_string_literal: true

class DestroyInstance
  attr_accessor :entities_to_destroy

  def initialize
    @entities_to_destroy = []
    @unfounded_entities = []

    files = Dir["#{Rails.root}app/models/*.rb"]
    @models = files.map { |m| File.basename(m, ".rb").camelize }
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def execute_kill_command(force = false)
    Customer.transaction do
      # GraphStep.delete([2,3,4])
      if !force && !@unfounded_entities.empty?
        puts "--> WARNING some entities has not been founded. if you are sure, use the force !"
        puts "--> entities not founded : #{@unfounded_entities}."
        return false
      else
        @entities_to_destroy.each do |entity|
          current_model_to_destroy = entity[:key].constantize
          ids_to_destroy = entity[:values]
          ids_to_destroy = [] << ids_to_destroy unless ids_to_destroy.is_a?(Array)
          puts "--> ids to destroy for model #{current_model_to_destroy} : "
          puts ids_to_destroy.to_s
          # TODO : some models doesn't clean the files properly. a rework is needed for :
          # GraphBackground, customer_setting, Resource, User
          # TODO : il faut aussi gérer le cas des orphelins et des fichiers uploadés orphelins...
          # rubocop:disable Metrics/BlockNesting
          if current_model_to_destroy.method_defined? :file
            # Call a destroy to delete the associated file
            ids_to_destroy.each do |id_to_destroy|
              if current_model_to_destroy.exists?(id_to_destroy)
                # The corresponding file must exists
                if !current_model_to_destroy.find(id_to_destroy).file.file.nil? &&
                   current_model_to_destroy.find(id_to_destroy).file.file.exists?

                  current_model_to_destroy.destroy(id_to_destroy)
                else
                  current_model_to_destroy.delete(id_to_destroy)
                end
              end
            end
          else
            # Call a delete to clean the DB avoiding some weird callbacks like Color model
            current_model_to_destroy.delete(ids_to_destroy)
          end
          # rubocop:enable Metrics/BlockNesting
        end
        return true
      end
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def kill_customer(customer, including_store = true)
    Customer.transaction do
      # Contient un hash key/values ; avec key=nom du model et values = ids des models.
      # Exemple : {key: "ActAttachment", values: [12, 18, 25]}

      customer_url = customer.url
      customer_id = customer.id
      puts "--> START OF kill_customer #{customer_url}(#{customer_id}) !! "
      user_ids = customer.users.pluck(:id)

      # Table act_attachments
      if @models.include? "ActAttachment"
        current_model = ActAttachment
        values = current_model.where(author_id: user_ids).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ActAttachment"
      end

      # Table act_domain_settings
      if @models.include? "ActDomainSetting"
        current_model = ActDomainSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ActDomainSetting"
      end

      # Table act_domains
      if @models.include? "ActDomain"
        current_model = ActDomain
        values = current_model.where(act_id: customer.acts.pluck(:id)).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ActDomain"
      end

      # Table act_eval_type_settings
      if @models.include? "ActEvalTypeSetting"
        current_model = ActEvalTypeSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ActEvalTypeSetting"
      end

      # Table act_type_settings
      if @models.include? "ActTypeSetting"
        current_model = ActTypeSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ActTypeSetting"
      end

      # Table act_verif_type_settings
      if @models.include? "ActVerifTypeSetting"
        current_model = ActVerifTypeSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ActVerifTypeSetting"
      end

      # Table acts
      if @models.include? "Act"
        current_model = Act
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Act"
      end

      # Table acts_events
      if @models.include? "ActsEvent"
        current_model = ActsEvent
        values = current_model.where(act: customer.acts).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ActsEvent"
      end

      # Table acts_validators
      if @models.include? "ActsValidator"
        current_model = ActsValidator
        values = current_model.where(act: customer.acts).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ActsValidator"
      end

      # Table arrows
      if @models.include? "Arrow"
        current_model = Arrow
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Arrow"
      end

      # Table audit_attachments
      if @models.include? "AuditAttachment"
        current_model = AuditAttachment
        values = current_model.where(audit: customer.audits).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "AuditAttachment"
      end

      # Table audit_element_subject_audit_events
      if @models.include? "AuditElementSubjectAuditEvent"
        current_model = AuditElementSubjectAuditEvent
        customer_audit_events = AuditEvent.where(audit: customer.audits)
        values = current_model.where(audit_event: customer_audit_events).pluck(:id)
      else
        @unfounded_entities << "AuditElementSubjectAuditEvent"
      end
      @entities_to_destroy << { key: current_model.to_s, values: values }

      # Table audit_element_subjects
      if @models.include? "AuditElementSubject"
        current_model = AuditElementSubject
        values = current_model.where(audit: customer.audits).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "AuditElementSubject"
      end

      # Table audit_elements
      if @models.include? "AuditElement"
        current_model = AuditElement
        values = current_model.where(audit: customer.audits).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "AuditElement"
      end

      # Table audit_events
      if @models.include? "AuditEvent"
        current_model = AuditEvent
        values = current_model.where(audit: customer.audits).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "AuditEvent"
      end

      # Table audit_participants
      if @models.include? "AuditParticipant"
        current_model = AuditParticipant
        audit_elements = AuditElement.where(audit: customer.audits)
        values = current_model.where(audit_element: audit_elements).pluck(:id)
      else
        @unfounded_entities << "AuditParticipant"
      end
      @entities_to_destroy << { key: current_model.to_s, values: values }

      # Table audit_theme_settings
      if @models.include? "AuditThemeSetting"
        current_model = AuditThemeSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "AuditThemeSetting"
      end

      # Table audit_themes
      if @models.include? "AuditThemeSetting"
        current_model = AuditThemeSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "AuditThemeSetting"
      end

      # Table audit_type_settings
      if @models.include? "AuditTypeSetting"
        current_model = AuditTypeSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "AuditTypeSetting"
      end

      # Table audits
      if @models.include? "Audit"
        current_model = Audit
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Audit"
      end

      # Table colors
      if @models.include? "Color"
        current_model = Color
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Color"
      end

      # Table contributables_contributors
      if @models.include? "ContributablesContributor"
        current_model = ContributablesContributor
        values = current_model.where(contributor: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ContributablesContributor"
      end

      # Table contributions
      if @models.include? "Contribution"
        current_model = Contribution
        values = current_model.where(user: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Contribution"
      end

      # Table customer_settings
      if @models.include? "CustomerSetting"
        current_model = CustomerSetting
        values = customer.settings.id
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "CustomerSetting"
      end

      # Table customer_sso_settings
      if @models.include? "CustomerSsoSetting"
        current_model = CustomerSsoSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "CustomerSsoSetting"
      end

      # Table directories
      if @models.include? "Directory"
        current_model = Directory
        values = customer.directories.pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Directory"
      end

      # Table document_publishers
      if @models.include? "DocumentPublisher"
        current_model = DocumentPublisher
        values = current_model.where(document: customer.documents).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "DocumentPublisher"
      end

      # Table documents
      if @models.include? "Document"
        current_model = Document
        values = customer.documents.pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Document"
      end

      # Table documents_approvers
      if @models.include? "DocumentsApprover"
        current_model = DocumentsApprover
        values = current_model.where(document: customer.documents).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "DocumentsApprover"
      end

      # Table documents_logs
      if @models.include? "DocumentsLog"
        current_model = DocumentsLog
        values = current_model.where(document: customer.documents).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "DocumentsLog"
      end

      # Table documents_verifiers
      if @models.include? "DocumentsVerifier"
        current_model = DocumentsVerifier
        values = current_model.where(document: customer.documents).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "DocumentsVerifier"
      end

      # Table documents_viewers
      if @models.include? "DocumentsViewer"
        current_model = DocumentsViewer
        values = current_model.where(document: customer.documents).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "DocumentsViewer"
      end

      # Table elements
      if @models.include? "Element"
        current_model = Element
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Element"
      end

      # Table event_attachments
      if @models.include? "EventAttachment"
        current_model = EventAttachment
        values = current_model.where(event: customer.events).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "EventAttachment"
      end

      # Table event_cause_settings
      if @models.include? "EventCauseSetting"
        current_model = EventCauseSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "EventCauseSetting"
      end

      # Table event_causes
      if @models.include? "EventCause"
        current_model = EventCause
        values = current_model.where(event: customer.events).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "EventCause"
      end

      # Table event_domain_settings
      if @models.include? "EventDomainSetting"
        current_model = EventDomainSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "EventDomainSetting"
      end

      # Table event_domains
      if @models.include? "EventDomain"
        current_model = EventDomain
        values = current_model.where(event: customer.events).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "EventDomain"
      end

      # Table event_type_settings
      if @models.include? "EventTypeSetting"
        current_model = EventTypeSetting
        values = current_model.where(customer_setting_id: customer.settings.id).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "EventTypeSetting"
      end

      # Table event_validators
      if @models.include? "EventValidator"
        current_model = EventValidator
        values = current_model.where(event: customer.events).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "EventValidator"
      end

      # Table events
      if @models.include? "Event"
        current_model = Event
        values = customer.events.pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Event"
      end

      # Table events_continuous_improvement_managers
      if @models.include? "EventsContinuousImprovementManager"
        current_model = EventsContinuousImprovementManager
        values = current_model.where(event: customer.events).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "EventsContinuousImprovementManager"
      end

      # Table external_users
      if @models.include? "ExternalUser"
        current_model = ExternalUser
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ExternalUser"
      end

      # Table favorites
      if @models.include? "Favorite"
        current_model = Favorite
        values = current_model.where(user: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Favorite"
      end

      # Table flags
      if @models.include? "Flag"
        current_model = Flag
        values = customer.flag.id
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Flag"
      end

      # Table graph_backgrounds
      if @models.include? "GraphBackground"
        current_model = GraphBackground
        values = customer.graphs.where.not(graph_background_id: nil).pluck(:graph_background_id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphBackground"
      end

      # Table graph_images
      if @models.include? "GraphImage"
        current_model = GraphImage
        values = current_model.where(owner: customer.settings).pluck(:id) +
                 current_model.where(owner: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphImage"
      end

      # Table graph_publishers
      if @models.include? "GraphPublisher"
        current_model = GraphPublisher
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphPublisher"
      end

      # Table graph_steps
      if @models.include? "GraphStep"
        current_model = GraphStep
        values = current_model.where(graph_id: customer.graphs.pluck(:id)).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphStep"
      end

      # Table graphs
      if @models.include? "Graph"
        current_model = Graph
        values = customer.graphs.pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Graph"
      end

      # Table graphs_approvers
      if @models.include? "GraphsApprover"
        current_model = GraphsApprover
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphsApprover"
      end

      # Table graphs_logs
      if @models.include? "GraphsLog"
        current_model = GraphsLog
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphsLog"
      end

      # Table graphs_roles
      if @models.include? "GraphsRole"
        current_model = GraphsRole
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphsRole"
      end

      # Table graphs_verifiers
      if @models.include? "GraphsVerifier"
        current_model = GraphsVerifier
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphsVerifier"
      end

      # Table graphs_viewers
      if @models.include? "GraphsViewer"
        current_model = GraphsViewer
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "GraphsViewer"
      end

      # Table groupdocuments
      if @models.include? "Groupdocument"
        current_model = Groupdocument
        values = customer.groupdocuments.pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Groupdocument"
      end

      # Table groupgraphs
      if @models.include? "Groupgraph"
        current_model = Groupgraph
        values = customer.groupgraphs.pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Groupgraph"
      end

      # Table grouppackages
      if including_store
        if @models.include? "Grouppackage"
          current_model = Grouppackage
          values = customer.grouppackages.pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "Grouppackage"
        end
      end

      # Table groups
      if @models.include? "Group"
        current_model = Group
        values = customer.groups.pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Group"
      end

      # Table image_categories
      if @models.include? "ImageCategory"
        current_model = ImageCategory
        values = current_model.where(owner: customer.settings).pluck(:id) +
                 current_model.where(owner: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ImageCategory"
      end

      # Table impactables_impacts
      if @models.include? "ImpactablesImpact"
        current_model = ImpactablesImpact
        values = current_model.where(impactable: customer.events).pluck(:id) +
                 current_model.where(impactable: customer.acts).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ImpactablesImpact"
      end

      # Table imported_packages
      if @models.include? "ImportedPackage"
        current_model = ImportedPackage
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ImportedPackage"
      end

      # Table lanes
      if @models.include? "Lane"
        current_model = Lane
        values = current_model.where(graph: customer.graphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Lane"
      end

      # Table localisations
      if @models.include? "Localisation"
        current_model = Localisation
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Localisation"
      end

      # Table localisings
      if @models.include? "Localising"
        current_model = Localising
        values = current_model.where(localisation: customer.localisations).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Localising"
      end

      # Table models
      if @models.include? "Model"
        current_model = Model
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Model"
      end

      # Table new_notifications
      if @models.include? "NewNotification"
        current_model = NewNotification
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "NewNotification"
      end

      # Table notifications
      if @models.include? "ProcessNotification"
        current_model = ProcessNotification
        values = current_model.where(sender: customer.users).pluck(:id) +
                 current_model.where(receiver: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ProcessNotification"
      end

      # Table package_arrows
      if including_store
        if @models.include? "PackageArrow"
          current_model = PackageArrow
          values = current_model.where(package_graph:
            PackageGraph.where(package: customer.packages)).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageArrow"
        end
      end

      # Table package_categories
      if including_store
        if @models.include? "PackageCategory"
          current_model = PackageCategory
          values = current_model.where(package: customer.packages).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageCategory"
        end
      end

      # Table package_connections
      if including_store
        if @models.include? "PackageConnection"
          current_model = PackageConnection
          values = current_model.where(package: customer.packages).pluck(:id) +
                   current_model.where(customer: customer).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageConnection"
        end
      end

      # Table package_documents
      if including_store
        if @models.include? "PackageDocument"
          current_model = PackageDocument
          values = current_model.where(package: customer.packages).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageDocument"
        end
      end

      # Table package_elements
      if including_store
        if @models.include? "PackageElement"
          current_model = PackageElement
          values = current_model.where(package_graph: PackageGraph.where(package: customer.packages)).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageElement"
        end
      end

      # Table package_graphs
      if including_store
        if @models.include? "PackageGraph"
          current_model = PackageGraph
          values = current_model.where(package: customer.packages).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageGraph"
        end
      end

      # Table package_lanes
      if including_store
        if @models.include? "PackageLane"
          current_model = PackageLane
          values = current_model.where(package_graph: PackageGraph.where(package: customer.packages)).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageLane"
        end
      end

      # Table package_pastilles
      if including_store
        if @models.include? "PackagePastille"
          current_model = PackagePastille
          values = current_model.where(package_element: PackageElement.where(
            package_graph: PackageGraph.where(package: customer.packages)
          )).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackagePastille"
        end
      end

      # Table package_resources
      if including_store
        if @models.include? "PackageResource"
          current_model = PackageResource
          values = current_model.where(package: customer.packages).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageResource"
        end
      end

      # Table package_roles
      if including_store
        if @models.include? "PackageRole"
          current_model = PackageRole
          values = current_model.where(package: customer.packages).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "PackageRole"
        end
      end

      # Table packages
      if including_store
        if @models.include? "Package"
          current_model = Package
          values = current_model.where(customer: customer).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "Package"
        end
      end

      # Table pastille_settings
      if @models.include? "PastilleSetting"
        current_model = PastilleSetting
        values = current_model.where(customer_setting: customer.settings).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "PastilleSetting"
      end

      # Table pastilles
      if @models.include? "Pastille"
        current_model = Pastille
        values = current_model.where(pastille_setting: PastilleSetting.where(
          customer_setting: customer.settings
        )).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Pastille"
      end

      # Table read_confirmations
      if @models.include? "ReadConfirmation"
        current_model = ReadConfirmation
        values = current_model.where(user: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ReadConfirmation"
      end

      # Table recordings
      if @models.include? "Recording"
        current_model = Recording
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Recording"
      end

      # Table reference_counters
      if @models.include? "ReferenceCounter"
        current_model = ReferenceCounter
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ReferenceCounter"
      end

      # Table reference_settings
      if @models.include? "ReferenceSetting"
        current_model = ReferenceSetting
        values = current_model.where(customer_setting: customer.settings).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ReferenceSetting"
      end

      # Table reminders
      if @models.include? "Reminder"
        current_model = Reminder
        values = current_model.where(from: customer.users).pluck(:id) +
                 current_model.where(to: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Reminder"
      end

      # Table resources
      if @models.include? "Resource"
        current_model = Resource
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Resource"
      end

      # Table review_histories
      if @models.include? "ReviewHistory"
        current_model = ReviewHistory
        values = current_model.where(groupgraph: customer.groupgraphs).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "ReviewHistory"
      end

      # Table role_attachments
      if @models.include? "RoleAttachment"
        current_model = RoleAttachment
        values = current_model.where(role: customer.roles).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "RoleAttachment"
      end

      # Table roles
      if @models.include? "Role"
        current_model = Role
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Role"
      end

      # Table roles_users
      if @models.include? "RolesUser"
        current_model = RolesUser
        values = current_model.where(role: customer.roles).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "RolesUser"
      end

      # Table schema_migrations
      # Nothing to do.

      # Table static_package_categories
      # Nothing to do.

      # Table store_connections
      if including_store
        if @models.include? "StoreConnection"
          current_model = StoreConnection
          values = current_model.where(customer: customer).pluck(:id) +
                   current_model.where(connection: customer).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "StoreConnection"
        end
      end

      # Table store_subscriptions
      if including_store
        if @models.include? "StoreSubscription"
          current_model = StoreSubscription
          values = current_model.where(subscription: customer).pluck(:id) +
                   current_model.where(user: customer.users).pluck(:id)
          @entities_to_destroy << { key: current_model.to_s, values: values }
        else
          @unfounded_entities << "StoreSubscription"
        end
      end

      # Table super_admins
      # Nothing to do.

      # Table taggings
      if @models.include? "Tagging"
        current_model = Tagging
        values = current_model.where(tag: Tag.where(customer: customer)).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Tagging"
      end

      # Table tags
      if @models.include? "Tag"
        current_model = Tag
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Tag"
      end

      # Table task_flags
      if @models.include? "TaskFlag"
        current_model = TaskFlag
        values = current_model.where(user: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "TaskFlag"
      end

      # Table timeline_acts
      if @models.include? "TimelineAct"
        current_model = TimelineAct
        values = current_model.where(act: customer.acts).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "TimelineAct"
      end

      # Table timeline_audits
      if @models.include? "TimelineAudit"
        current_model = TimelineAudit
        values = current_model.where(audit: customer.audits).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "TimelineAudit"
      end

      # Table timeline_events
      if @models.include? "TimelineEvent"
        current_model = TimelineEvent
        values = current_model.where(event: customer.events).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "TimelineEvent"
      end

      # Table user_attachments
      if @models.include? "UserAttachment"
        current_model = UserAttachment
        values = current_model.where(user: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "UserAttachment"
      end

      # Table users_groups
      if @models.include? "UsersGroup"
        current_model = UsersGroup
        values = current_model.where(user: customer.users).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "UsersGroup"
      end

      # Table users
      if @models.include? "User"
        current_model = User
        values = current_model.where(customer: customer).pluck(:id)
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "User"
      end

      # Table customers
      if @models.include? "Customer"
        current_model = Customer
        values = customer.id
        @entities_to_destroy << { key: current_model.to_s, values: values }
      else
        @unfounded_entities << "Customer"
      end

      # Test for inexistant model
      # if @models.include? "NoExist"
      #   current_model = NoExist
      #   values = current_model.where(:user => customer.users).pluck(:id)
      #   @entities_to_destroy << {key: current_model.to_s, values: values}
      # else
      #   @unfounded_entities << "NoExist"
      # end

      puts "--> END OF kill_customer #{customer_url}(#{customer_id}) !! "
      return true
    end
  rescue StandardError => e
    puts "--> ERROR APPEND !! "
    Rails.logger.error(e.message)
    Rails.logger.error e.backtrace.join("\n")
    false
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
end
