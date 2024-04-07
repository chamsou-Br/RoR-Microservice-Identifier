class ASTExtractor < Parser::AST::Processor
    attr_reader :class_name, :methods_list, :called_methods , :module_name , :receivers , :global_attributes
  
    def initialize
      @class_name = nil
      @methods_list = []
      @global_attributes = []
      @called_methods = Hash.new { |h, k| h[k] = [] }
      @receivers = []
      @module_name = nil
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
      @methods_list << { name: method_name.to_s , num_args: num_args } if @class_name
      super
    end
  
    def on_send(node)
      receiver, method_name ,  *arguments = node.children
      num_args = arguments.size
      if receiver && receiver.type == :send && receiver.children[1].is_a?(Symbol)
        receiver_name = receiver.children[1].to_s
      elsif receiver && receiver.type == :const
        receiver_name = receiver.children[1].to_s
      else
        receiver_name = receiver.nil? ? class_name : ""
      end
      @called_methods[current_method ? current_method[:name] : ""] << { name: method_name.to_s, num_args: num_args }
      @receivers << receiver_name
      super
    end
  
    def current_method
      @methods_list.last
    end

  end

  def get_class_info(ast)
    extractor = ASTExtractor.new
    extractor.process(ast)
    [extractor.class_name, extractor.methods_list , extractor.called_methods , extractor.module_name , extractor.receivers ]
  end