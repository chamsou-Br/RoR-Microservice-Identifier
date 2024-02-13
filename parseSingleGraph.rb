require 'parser/current'

puts "Enter your file path"
path = gets.chomp
puts "You entered: #{path}"

puts "\n-------------------------------   START   -------------------------------\n\n"
source_code = File.read(path)

buffer = Parser::Source::Buffer.new(path).tap do |buffer| 
    buffer.source = source_code
end

parser = Parser::CurrentRuby.new

ast = parser.parse(buffer)

File.write('parse_ast.txt', ast)

class ClassNameExtractor < Parser::AST::Processor
    attr_reader :class_name, :methods_list, :called_methods
  
    def initialize
      @class_name = nil
      @methods_list = []
      @called_methods = Hash.new { |h, k| h[k] = [] }
    end
  
    def on_class(node)
      class_name_node = node.children[0]
      @class_name = class_name_node.children[1] if class_name_node.type == :const
      super
    end
  
    def on_def(node)
      method_name = node.children[0]
      @methods_list << method_name if @class_name
      super
    end
  
    def on_send(node)
      receiver, method_name = node.children
      return unless receiver.nil? # We only consider method calls without a receiver
      @called_methods[current_method] << method_name
      super
    end
  
    def current_method
      @methods_list.last
    end
  end
  
  def get_class_info(ast)
    extractor = ClassNameExtractor.new
    extractor.process(ast)
    [extractor.class_name, extractor.methods_list, extractor.called_methods]
  end

  def format_calls_architecture(methods_list , called_methods)
    calls_architecture = []
  
    methods_list.each do |calling_method|
      called_methods_list = called_methods[calling_method] || []
      formatted_method = {
        calling_method: calling_method.to_s,
        called_methods: called_methods_list.map(&:to_s)
      }
      calls_architecture << formatted_method
    end
  
    return calls_architecture
  end
  

  def geDotFileObject(structure)
    desired_table = []
    dot_line = ""
  
    structure[:methods].each do |method|
        called_methods = method[:called_methods]
        calling_method = method[:calling_method]
  
        if (calling_method !~ /[\[\],]/) #if calling_method does not contain [ or ] or ,
          if (calling_method.include?("?"))
            calling_method.sub!("?", "")
          elsif (calling_method.include?("!"))
            calling_method.sub!("!", "")
          end
  
          if method[:called_methods].empty?
              dot_line = calling_method + ";"
              desired_table.push(dot_line)
          else
              called_methods.each do |called_method|
                  if (called_method.include?("?"))
                      called_method.sub!("?", "")
                      dot_line = calling_method + " -> " + called_method + ";"
                  elsif (called_method.include?("!"))
                      called_method.sub!("!", "")
                      dot_line = calling_method + " -> " + called_method + ";"
                  else
                      dot_line = calling_method + " -> " + called_method + ";"
                  end
                  desired_table.push(dot_line)
              end
          end
        end
  
      end
  
    return desired_table
  end

  def createDotFile(dot_structure)
    File.open("call_graph.dot", "w") do |file|
        file.puts 'digraph CallGraph {'
        dot_structure.each do |entry|
            file.puts entry
        end
        file.puts '}'
    end
  end
  
  class_name, methods_list, called_methods = get_class_info(ast)
  puts "Class name: #{class_name.inspect}"
  puts "Methods: #{methods_list.inspect}"
  puts "Called methods: #{called_methods.inspect}"

  class_structure = {
  class: class_name,
  methods: format_calls_architecture(methods_list , called_methods)
}

dot_structure = geDotFileObject(class_structure) 

createDotFile(dot_structure)

puts "\n-------------------------------   END   -------------------------------\n"

system("dot -Tsvg call_graph.dot -o call_graph.svg")

  