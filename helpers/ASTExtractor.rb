class ASTExtractor < Parser::AST::Processor
    attr_reader :class_name, :methods_list, :variables ,:called_methods , :module_name , :receivers , :global_attributes
  
    def initialize
      @class_name = nil
      @methods_list = []
      @global_attributes = []
      @called_methods = Hash.new { |h, k| h[k] = [] }
      @receivers = []
      @module_name = nil
      @variables = {}
    end
  
    def on_module(node)
      module_name_node = node.children[0]
      @module_name = module_name_node.children[1].to_s if module_name_node.type == :const
      super
    end
  
    def on_class(node)
      class_name_node = node.children[0]
      @class_name = class_name_node.children[1] if class_name_node.type == :const
      super
    end
  
    def on_ivar(node)
      ivar_name = node.children.first.to_s
      @global_attributes << ivar_name
      super
    end
  
    def on_def(node)
      method_name, args, _body = node.children
      num_args = args.children.size
      @methods_list << { name: method_name.to_s , num_args: num_args  } if @class_name || @module_name
      super
    end
  
    def on_send(node)
      receiver, method_name ,  *arguments = node.children
      num_args = arguments.size
      receiver_name = extract_receiver_name(receiver)
      @called_methods[current_method ? current_method[:name] : ""] << { name: method_name.to_s, num_args: num_args , reciever:  receiver_name}
      @receivers << receiver_name
      super
    end

    def on_ivasgn(node)
      variable_name = node.children[0].to_s
      variable_value = node.children[1]
    
      method_name = nil
      receiver_class = nil
    
      if variable_value.is_a?(Parser::AST::Node)
        if variable_value.type == :send
          method_name = variable_value.children[1].to_s
          receiver = variable_value.children[0]
          receiver_class = receiver.children[1].to_s if receiver && receiver.type == :const
        elsif variable_value.type == :const
          method_name = variable_value.children[1].to_s
          receiver_class = variable_value.children[1].to_s
        end
      end

      if receiver_class && method_name == "new"
        data = { name: variable_name, value: receiver_class }
        if @variables.key?(current_method[:name])
          @variables[current_method[:name]] << data
        else
          @variables[current_method[:name]] = [data]
        end
      end

    super
    end
  
    def on_lvasgn(node)
      variable_name = node.children[0].to_s
      variable_value = node.children[1]
    
      method_name = nil
      receiver_class = nil
    
      if variable_value.is_a?(Parser::AST::Node)
        if variable_value.type == :send
          method_name = variable_value.children[1].to_s
          receiver = variable_value.children[0]
          receiver_class = receiver.children[1].to_s if receiver && receiver.type == :const
        elsif variable_value.type == :const
          method_name = variable_value.children[1].to_s
          receiver_class = variable_value.children[1].to_s
        end
      end

      if receiver_class && method_name == "new"
        data = { name: variable_name, value: receiver_class }
        if @variables.key?(current_method[:name])
          @variables[current_method[:name]] << data
        else
          @variables[current_method[:name]] = [data]
        end
      end
    
      super
    end

    def current_method
      @methods_list.last
    end

    private

    def extract_receiver_name(receiver)
      return "self" unless receiver
  
      case receiver.type
      when :send
        receiver.children[1].to_s
      when :const
        receiver.children[1].to_s
      when :lvar
        receiver.children[0].to_s
      when :ivar
        receiver.children[0].to_s
      else
        ""
      end
    end

  end

  def get_class_info(ast)
    extractor = ASTExtractor.new
    extractor.process(ast)
    class_name = extractor.class_name || extractor.module_name
    [class_name, extractor.methods_list , extractor.called_methods , extractor.module_name , extractor.receivers , extractor.variables ]
  end