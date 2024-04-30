# frozen_string_literal: true

class ScanInstance
  attr_accessor :res_errors, :res_warnings, :error_elements, :error_graphs_roles, :customers, :error_pastilles

  def initialize
    @res_errors = []
    @res_warnings = []
    @error_elements = []
    @error_parent_role_on_elements = []
    @error_parent_id_on_elements = []
    @error_pastille_role_ids = []
    @error_graphs_roles = []
    @customers = []
    @error_pastilles = []
  end

  def add_customer(customer)
    @customers << customer
  end

  def add_customers(customers)
    customers.each do |customer|
      @customers << customer
    end
  end

  def clear_errors
    @res_errors = []
    @res_warnings = []
    @error_elements = []
    @error_parent_role_on_elements = []
    @error_parent_id_on_elements = []
    @error_pastille_role_ids = []
    @error_graphs_roles = []
    @error_pastilles = []
  end

  def clear
    clear_errors
    @customers = []
  end

  def auto_set_error_pastilles_to_unknown(error_pastilles = @error_pastilles)
    error_pastilles.each do |error_pastille|
      settings = error_pastille.element.graph.customer.settings
      pastille_setting_unknown = settings.pastilles.where(desc_en: "Unknown").first
      error_pastille.pastille_setting = pastille_setting_unknown
      error_pastille.save
      puts "--> error_pastille.id #{error_pastille.id} responsability setted to unknown."
    end
  end

  def auto_unlink_error_elements(error_elements = @error_elements)
    error_elements.each do |error_element|
      error_element.model_id = nil
      error_element.model_type = nil
      error_element.save
      puts "--> error_element.id #{error_element.id} (#{error_element.text}) unlinked."
    end
  end

  def auto_unlink_error_parent_role_on_elements(error_parent_role_on_elements = @error_parent_role_on_elements)
    error_parent_role_on_elements.each do |error_parent_role_on_element|
      error_parent_role_on_element.parent_role = nil
      error_parent_role_on_element.save
      puts "--> error_parent_role_on_element.id #{error_parent_role_on_element.id} "\
           "(#{error_parent_role_on_element.text}) has no more fake parent_role."
    end
  end

  def auto_unlink_error_parent_id_on_elements(error_parent_id_on_elements = @error_parent_id_on_elements)
    error_parent_id_on_elements.each do |error_parent_id_on_element|
      error_parent_id_on_element.parent_id = nil
      error_parent_id_on_element.save
      puts "--> error_parent_id_on_element.id #{error_parent_id_on_element.id} "\
           "(#{error_parent_id_on_element.text}) has no more fake parent_id."
    end
  end

  def auto_destroy_error_pastille_role_ids(error_pastille_role_ids = @error_pastille_role_ids)
    error_pastille_role_ids.each do |error_pastille_role_id|
      error_pastille_role_id.destroy
      puts "--> pastille with a role that's doesn't exists was deleted."
    end
  end

  def auto_destroy_graphs_roles(error_graphs_roles = @error_graphs_roles)
    error_graphs_roles.each do |error_graph_role|
      puts "--> destroying error_graph_role.id #{error_graph_role.id} (#{error_graph_role.inspect})..."
      error_graph_role.destroy
      puts "destroy done."
    end
  end

  def check_not_linked_or_linked_entity_exists(element)
    if element.model_id.nil?
      true
    elsif !element.model_type.nil?
      element.model_type.constantize.exists?(element.model_id)
    else
      Role.exists?(element.model_id)
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def scan(wk_customers = @customers)
    # wk_customers << Customer.where(:url => "cumfin.migration.qualiproto.fr").first
    # wk_customers = Customer.all.to_a
    # On clear les errors...
    clear_errors

    wk_customers.each do |c|
      # On reload également les customers (synchro BDD nécessaire dans le cas d'un second passage du scan)
      c.reload
      c.graphs.each do |graph|
        graph.elements.each do |element|
          puts "Controlling element(id:#{element.id}[updated_at=#{element.updated_at}]) of "\
               "graph(id:#{graph.id}) of customer(id:#{c.id}, url:#{c.url})..."
          if !check_not_linked_or_linked_entity_exists(element)
            @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graph "\
                           "#{graph.id}(#{graph.state}) : Entity linked to element.id "\
                           "#{element.id}[updated_at=#{element.updated_at}] (#{element.text}) "\
                           " doesn't exists !"
            @error_elements << element
          elsif !element.model_type.nil?
            if element.model_id.nil?
              @res_warnings << " [customer(#{c.id}): #{c.url} ] Warning on graph #{graph.id} "\
                               ": element.id #{element.id}[updated_at=#{element.updated_at}]"\
                               " (#{element.text}) has a model_type but no model_id !"
            else
              linked_entity = element.model_type.constantize.find(element.model_id)
              if linked_entity.customer != c
                @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graph "\
                               "#{graph.id}(#{graph.state}) : Bad customer on model linked"\
                               " to element.id #{element.id}[updated_at=#{element.updated_at}]"\
                               " (#{element.text})"
                @error_elements << element
              end
            end
          elsif !element.model_id.nil?
            if %w[role relatedRole].include?(element.shape)
              gg = Role.find(element.model_id)
              if gg.customer != c
                @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graph "\
                               " #{graph.id}(#{graph.state}) : Bad customer on model linked"\
                               " to element.id #{element.id}[updated_at=#{element.updated_at}]"\
                               " (#{element.text})"
                @error_elements << element
              end
            else
              @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graph "\
                             "#{graph.id}(#{graph.state}) : unknown shape for"\
                             " element.id #{element.id}[updated_at=#{element.updated_at}]"\
                             " (#{element.text}) with element.shape #{element.shape}"
              @error_elements << element
            end
          end

          if !element.parent_role.nil? && element.parent_role != 0
            if Element.exists?(element.parent_role)
              parent_role = Element.find(element.parent_role)
              if parent_role.graph_id != graph.id
                @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graph "\
                               "#{graph.id}(#{graph.state}) : element.id"\
                               " #{element.id}[updated_at=#{element.updated_at}] "\
                               "(#{element.text}) refers to parent_role(#{element.parent_role})"\
                               " that belong's to an other graph !"
                @error_parent_role_on_elements << element
              end
            else
              @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graph "\
                             "#{graph.id}(#{graph.state}) : element.id #{element.id}"\
                             "[updated_at=#{element.updated_at}] (#{element.text}) refers"\
                             " to parent_role(#{element.parent_role}) that doesn't exists !"
              @error_parent_role_on_elements << element
            end
          end
          unless element.parent_id.nil?
            if Element.exists?(element.parent_id)
              parent_id = Element.find(element.parent_id)
              if parent_id.graph_id != graph.id
                @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graph"\
                               " #{graph.id}(#{graph.state}) : element.id #{element.id}"\
                               "[updated_at=#{element.updated_at}] (#{element.text}) refers to"\
                               " parent_id(#{element.parent_id}) that belong's to an other graph !"
                @error_parent_id_on_elements << element
              end
            else
              @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graph "\
                             "#{graph.id}(#{graph.state}) : element.id #{element.id}"\
                             "[updated_at=#{element.updated_at}] (#{element.text}) refers"\
                             " to parent_id(#{element.parent_id}) that doesn't exists !"
              @error_parent_id_on_elements << element
            end
          end

          next unless element.pastilles.count.positive?

          puts "Controlling pastilles of element(id:#{element.id}"\
               "[updated_at=#{element.updated_at}]) of graph(id:#{graph.id})"\
               " of customer(id:#{c.id}, url:#{c.url})..."
          element.pastilles.each do |pastille|
            if pastille.pastille_setting_id.nil? || pastille.pastille_setting_id.zero?
              @res_errors << " [customer(#{c.id}): #{c.url} ] Error on pastille #{pastille.id}"\
                             " in graph #{graph.id}(#{graph.state}) : pastille linked to"\
                             " element.id #{element.id}[updated_at=#{element.updated_at}]"\
                             " (#{element.text}) has a BAD"\
                             " pastille_setting_id(#{pastille.pastille_setting_id}) !"
              @error_pastilles << pastille
            end

            next unless !Element.exists?(pastille.role_id) || Element.find(pastille.role_id).graph_id != graph.id

            @res_errors << " [customer(#{c.id}): #{c.url} ] Error on pastille #{pastille.id}"\
                           " in graph #{graph.id}(#{graph.state}) : pastille linked to"\
                           " role_id #{pastille.role_id} that's doesn't exists !"
            @error_pastille_role_ids << pastille
          end
        end

        graph.graphs_roles.each do |gr|
          puts "Controlling graph_role(id:#{gr.id}) of graph(id:#{graph.id}) of"\
               " customer(id:#{c.id}, url:#{c.url})..."
          role = gr.role
          if role.nil?
            @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graphs_roles"\
                           " #{gr.id} : Entity role(#{gr.role_id}) linked to"\
                           " graph(#{graph.state}) throw graphs_roles doesn't exists !"
            @error_graphs_roles << gr
          elsif role.customer != c
            @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graphs_roles"\
                           " #{gr.id} : Bad customer on role linked to"\
                           " graph.id #{graph.id}(#{graph.state}) (#{graph.title})"
            @error_graphs_roles << gr
          end
        end
      end

      c.roles.each do |role|
        role.graphs_roles.each do |gr|
          puts "Controlling graph_role(id:#{gr.id}) of role(id:#{role.id}) of"\
               " customer(id:#{c.id}, url:#{c.url})..."
          graph = gr.graph
          next unless graph.customer != c

          @res_errors << " [customer(#{c.id}): #{c.url} ] Error on graphs_roles"\
                         " #{gr.id} : Bad customer on graph linked to role.id"\
                         " #{role.id} (#{role.title})"
          @error_graphs_roles << gr
        end
      end

      # Scanning entities.valid?
      c.graphs.each do |graph|
        puts "Controlling graph(id:#{graph.id} of customer(id:#{c.id}, url:#{c.url})..."
        unless graph.valid?
          @res_warnings << " [customer(#{c.id}): #{c.url} ] Error on graph"\
                           " #{graph.id}(#{graph.state}) : valid? failed"\
                           " ! : #{graph.errors.messages}"
        end
        graph.elements.each do |element|
          unless element.valid?
            @res_warnings << " [customer(#{c.id}): #{c.url} ] Error on element"\
                             " #{element.id} : valid? failed ! : #{element.errors.messages}"
          end
        end
      end

      c.settings.pastilles.each do |pastille|
        puts "Controlling pastille(id:#{pastille.id} of customer(id:#{c.id}, url:#{c.url})..."
        #
        # NOTE: following #1941, RACI pastilles are allowed to be edited. As
        # such checking for the validity of all pastilles here makes sense.
        # There are not tests for this scanner, and producing one now will be
        # very lengthy as this is a complex method whose innards I do not know.
        #
        unless pastille.valid?
          @res_warnings << " [customer(#{c.id}): #{c.url} ] Error on pastille"\
                           " #{pastille.id} : valid? failed ! : #{pastille.errors.messages}"
        end
      end

      c.documents.each do |document|
        puts "Controlling document(id:#{document.id} of customer(id:#{c.id}, url:#{c.url})..."
        next if document.valid?

        @res_warnings << " [customer(#{c.id}): #{c.url} ] Error on document"\
                         " #{document.id}(#{document.state}) : valid? failed"\
                         " ! : #{document.errors.messages}"
      end

      c.roles.each do |role|
        puts "Controlling role(id:#{role.id} of customer(id:#{c.id}, url:#{c.url})..."
        unless role.valid?
          @res_warnings << " [customer(#{c.id}): #{c.url} ] Error on role"\
                           " #{role.id} : valid? failed ! : #{role.errors.messages}"
        end
      end

      c.tags.each do |tag|
        puts "Controlling tag(id:#{tag.id} of customer(id:#{c.id}, url:#{c.url})..."
        unless tag.valid?
          @res_warnings << " [customer(#{c.id}): #{c.url} ] Error on tag"\
                           " #{tag.id} : valid? failed ! : #{tag.errors.messages}"
        end
      end
    end

    results
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def results
    puts "Scan finished : #{@res_errors.count} errors ; #{@res_warnings.count} warnings."
    if @res_errors.count.positive?
      puts "***** ERRORS DETAILS *****"
      @res_errors.each do |res_error|
        puts "ERROR --> #{res_error}"
      end
      puts "***** EOF *****"
    end

    return if @res_warnings.count.zero?

    puts "***** WARNINGS DETAILS *****"
    @res_warnings.each do |res_warning|
      puts "WARNING --> #{res_warning}"
    end
    puts "***** EOF *****"
  end
end
