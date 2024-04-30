
class ASTParserClass

    attr_reader :path , :class ,  :ast

    def initialize(file_path , source_code , type)
        @path = file_path

        buffer = Parser::Source::Buffer.new(file_path).tap do |buffer| 
            buffer.source = source_code
         end
    
        parser = Parser::CurrentRuby.new
    
        @ast = parser.parse(buffer)

        extractor = ASTExtractor.new
        extractor.process(ast)
        class_name = extractor.class_name || extractor.module_name
        if (type == ClassType::ClassController)
            @class = ClassNode.new(class_name.to_s,extractor.module_name,ClassType::ClassController,extractor.methods_list,extractor.receivers , extractor.called_methods)
        else
            @class = ClassNode.new(class_name.to_s,extractor.module_name,ClassType::DataEntity,[] , [] , [])
        end        
        
    end


    def get_class_info
        @class
    end

    def get_ast
        @ast
    end

end