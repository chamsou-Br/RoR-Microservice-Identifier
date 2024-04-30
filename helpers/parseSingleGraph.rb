require 'parser/current'


if ARGV.size != 1
  puts "\n\n"
  puts   "----------------------------------------------------"
  puts   "|          Usage: ruby single.rb <argument>        |"
  puts   "----------------------------------------------------"
  puts "\n"
  exit 1
end

# Concatenate the arguments into a single string
path = ARGV.join(' ')

# puts "Enter your file path"
# path = gets.chomp
# puts "You entered: #{path}"


source_code = File.read(path)

buffer = Parser::Source::Buffer.new(path).tap do |buffer| 
    buffer.source = source_code
end

parser = Parser::CurrentRuby.new

ast = parser.parse(buffer)



File.write('./output/parse_ast.txt', ast)

  class ASTExtractor < Parser::AST::Processor
    attr_reader :class_name, :methods_list, :called_methods , :module_name , :receivers
  
    def initialize
      @class_name = nil
      @methods_list = []
      @called_methods = Hash.new { |h, k| h[k] = [] }
      @receivers = Hash.new { |h, k| h[k] = [] }
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
  
    def on_def(node)
      method_name = node.children[0]
      @methods_list << method_name if @class_name || @module_name
      super
    end
  
    def on_send(node)
      receiver, method_name = node.children
      if receiver && receiver.type == :send && receiver.children[1].is_a?(Symbol)
        receiver_name = receiver.children[1].to_s
      else
        receiver_name = receiver.nil? ? 'self' : process(receiver)
      end
      @called_methods[current_method] << method_name
      @receivers[current_method] << receiver_name
      super
    end
  
    def current_method
      @methods_list.last
    end
  end
  
  def get_class_info(ast)
    extractor = ASTExtractor.new
    extractor.process(ast)
    [extractor.class_name, extractor.methods_list, extractor.called_methods]
  end

  def format_calls_architecture(methods_list , called_methods)
    calls_architecture = []
  
    methods_list.each do |calling_method|
      called_methods_list = called_methods[calling_method] || []
      filtered_called_methods = called_methods_list.select { |method| methods_list.include?(method) }
      formatted_method = {
        calling_method: calling_method.to_s,
        called_methods: filtered_called_methods.map(&:to_s)
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
    File.open("./output/call_graph_single.dot", "w") do |file|
      file.puts 'digraph CallGraph {'
      file.puts "node [shape=box, style=filled, fillcolor=lightblue  , color=white]"
      file.puts 'ranksep=5;'
      file.puts 'nodesep=0.5;'
      file.puts "node [fontname=Arial];"
      file.puts "edge [fontname=Arial];"
        dot_structure.each do |entry|
            file.puts entry
        end
        file.puts '}'
    end
  end
  
  class_name, methods_list, called_methods = get_class_info(ast)
  puts "\nClass name: #{class_name.inspect}"
  puts "\nMethods: #{methods_list.inspect}"
  puts "\nCalled methods: #{called_methods.inspect}"

  class_structure = {
  class: class_name,
  methods: format_calls_architecture(methods_list , called_methods)
}

dot_structure = geDotFileObject(class_structure) 

createDotFile(dot_structure)



system("dot -Tsvg ./output/call_graph_single.dot -o ./output/call_graph_single.svg")

puts "\n\ file done => ./output/call_graph_single.dot => ./output/call_graph_single.svg "

  