
require 'parser/current'


folder_path = "./global_files"

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
      @methods_list << method_name if @class_name
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

def count_files(folder_path)
    file_count = 0
    Dir.glob(File.join(folder_path, "*")).each do |item|
      if File.file?(item)
        # Increment the file count
        file_count += 1
      elsif File.directory?(item)
        # Recursive call if the item is a subdirectory
        file_count += count_files(item)
      end
    end
  
    return file_count
  end
  total_files = count_files(folder_path) # store number of files

  # Return file name including its parent folder
def get_file_name(file_path)
    parent_folder = File.basename(File.dirname(file_path))
    file_name = parent_folder + "/" + File.basename(file_path, ".*")
    file_name = "callgraphs/" + file_name
    return file_name
  end
  
  def getFilesFromFolder(folder_path)
    files_list = []
  
    Dir.glob(File.join(folder_path, "**/*")).each do |item|
      files_list << item if File.file?(item)
    end
  
    files_list
  end

  def get_class_info(ast)
    extractor = ASTExtractor.new
    extractor.process(ast)
    [extractor.class_name, extractor.methods_list, extractor.called_methods , extractor.module_name , extractor.receivers]
  end

  def format_calls_architecture(methods_list , called_methods , recievers)
    calls_architecture = []
  
    methods_list.each do |calling_method|
      called_methods_list = called_methods[calling_method] || []
      recievers_list = recievers[calling_method] || []
      formatted_method = {
        calling_method: calling_method.to_s,
        called_methods: called_methods_list.map(&:to_s),
        recievers: recievers_list
      }
      calls_architecture << formatted_method
    end
  
    return calls_architecture
  end
  

#------- MANAGE DOTFILE -------#
# create a table with a dot file structure by taking the calling methods
# in addition to called methods and add "-> & ;""
def geDotFileObject(structure,all_methods,class_of_all_methods)
    desired_table = []
    dot_line = "" #each line of the dot file
    class_name = structure[:class]
  
    # predefined methods excluded from the call graph
    not_needed_methods = ['send', 'new', 'initialize', 'find', 'save', 'update', 'delete', 'destroy', 'join',
                          'split', 'sort', 'length', 'size', 'count', 'get', 'set', 'include', 'is_a']
  
    structure[:methods].each do |method|
        called_methods = method[:called_methods]
        calling_method = method[:calling_method] 
  
        if (calling_method !~ /[\[\],]/) #if calling_method does not contain [ or ] or ,
          if (calling_method.include?("?"))
            calling_method.sub!("?", "")
          elsif (calling_method.include?("!"))
            calling_method.sub!("!", "")
          end
  
          if (!method[:called_methods].empty?)
              called_methods.each do |called_method|
                  class_of_called_method = class_of_all_methods[all_methods.index(called_method.to_sym)] || ""
                  if (called_method.include?("?"))
                      called_method.sub!("?", "")
                      dot_line = class_name.to_s + '_' + calling_method + " -> " + class_of_called_method + '_' + called_method + ";"
                  elsif (called_method.include?("!"))
                      called_method.sub!("!", "")
                      dot_line = class_name.to_s + '_' + calling_method + " -> " + class_of_called_method + '_' + called_method + ";"
                  elsif (called_method.length == 1 || not_needed_methods.include?(called_method)) # to remove calls of methods like "t" or "l" + remove calls of "new"
                    dot_line = class_name.to_s + '_' + calling_method + ";"
                  else
                    dot_line = class_name.to_s + '_' + calling_method + " -> " + class_of_called_method + '_' + called_method + ";"
                  end
                  puts dot_line
                  puts "\n\n"
                  desired_table.push(dot_line)
              end
          end
        end
  
      end
  
    return desired_table
  end

    # copy content of the table into the dot file
def createDotFile(dot_structure, file_name)
    dot_file_path = './call_graph.dot'
  
    File.open(dot_file_path, "a") do |file|
      file.puts 'digraph CallGraph {'
      file.puts 'ranksep=10;'
      file.puts 'nodesep=1;'
      dot_structure.each do |entry|
        file.puts entry
      end
      # file.puts '}'
    end
  
    dot_file_content = File.read(dot_file_path)
    unique_lines = dot_file_content.lines.uniq # Remove repeated lines
    File.write(dot_file_path, unique_lines.join) # Write the updated content back to the dot file
  end

  def appendClosingBrace(file_path)
    File.open(file_path, "a") do |file|
      file.puts '}' # Write "}" on a new line at the end of the file
    end
  end
  
  # Modifies the graph word if found because it is predefined in GraphViz
  def modify_graph_word(file_path)
    updated_lines = []
  
    File.open(file_path, "r") do |file|
      file.each_line do |line|
        modified_line = line.gsub(/\bgraph\b/, 'graphe') # Replace exact word "graph" with "graphe"
        updated_lines << modified_line
      end
    end
  
    File.open(file_path, "w") do |file|
      file.puts updated_lines
    end
  end

  # Delete methods that doesn't call any other methods
def filterDotFile(dot_file_path)
    filtered_lines = []
  
    # Read the dot file and filter lines that contain "->"
    File.open(dot_file_path, "r") do |file|
      file.each_line do |line|
        filtered_lines << line if line.include?("->") || line.include?("{") || line.include?("ranksep") || line.include?("nodesep")
      end
    end
  
    # Write the filtered lines back to the input file
    File.open(dot_file_path, "w") do |file|
      filtered_lines.each { |line| file.puts line }
    end
  end

def colorLinks(dot_file_path, focus_attribute)
    lines = File.readlines(dot_file_path)
  
    modified_lines = lines.map do |line|
      if line.include?(focus_attribute)
        line.gsub(";", " [color=blue];")
      else
        line
      end
    end
      # method_to_fill = focus_attribute.split("_").first # Get only the method name
  modified_lines << ("#{focus_attribute} [fillcolor=blue, style=filled, fontcolor=white, penwidth=0]")
  File.write(dot_file_path, modified_lines.join)
end



files_list = getFilesFromFolder(folder_path) #return paths of all files inside a folder in addition to its children folders
all_methods = []
class_of_all_methods = []
all_dots = []


for i in 0..(files_list.length-1)

    file_path = files_list[i]
    file_name = get_file_name(file_path) #return filename from the file path
  
    source_code = File.read(files_list[i])
  
    buffer = Parser::Source::Buffer.new(files_list[i]).tap do |buffer| 
          buffer.source = source_code
     end
  
    parser = Parser::CurrentRuby.new
  
    ast = parser.parse(buffer)
  
    File.write('parse_ast.txt', ast)

    class_name, methods_list, called_methods , module_name , receivers = get_class_info(ast)

  class_structure = {
    module: module_name,
    class: class_name,
    methods: format_calls_architecture(methods_list , called_methods , receivers) 
  }


  methods_list.each do |calling_method| 
    class_of_all_methods << class_name.to_s
  end

  all_methods.concat(methods_list)

  all_dots << class_structure

end

for i in 0..(all_dots.length-1)


    file_path = files_list[i]
    file_name = get_file_name(file_path)

    class_structure = all_dots[i]


    class_structure[:methods].each do |method|
        method[:called_methods].select! { |m| all_methods.include?(m.to_sym) }
    end


    dot_structure = geDotFileObject(class_structure , all_methods , class_of_all_methods) 

    createDotFile(dot_structure , file_name)

end
dot_file_path = "./call_graph.dot"
filterDotFile(dot_file_path) # delete methods that doesn't call any other methods
appendClosingBrace(dot_file_path)


system("dot -Tsvg call_graph.dot -o global_callGraph.svg")


