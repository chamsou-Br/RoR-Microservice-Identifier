require 'parser/current'


folder_path = "./global_files"

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

  class ClassNameExtractor < Parser::AST::Processor
    attr_reader :class_name, :methods_list, :called_methods , :module_name
  
    def initialize
      @class_name = nil
      @methods_list = []
      @called_methods = Hash.new { |h, k| h[k] = [] }
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
    [extractor.class_name, extractor.methods_list, extractor.called_methods , extractor.module_name]
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


  def createDotFile(dot_structure, file_name)
    dot_file_path = './call_graph.dot'
    File.open("call_graph.dot", "w") do |file|
        file.puts 'digraph CallGraph {'
        dot_structure.each do |entry|
            file.puts entry
        end
        file.puts '}'
    end
  
    dot_file_content = File.read(dot_file_path)
    unique_lines = dot_file_content.lines.uniq 
    File.write("call_graph.dot", unique_lines.join)
  end

all_methods = []
all_dots = []
  
files_list = getFilesFromFolder(folder_path) #return paths of all files inside a folder in addition to its children folders


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

  class_name, methods_list, called_methods , module_name = get_class_info(ast)

  class_structure = {
    module: module_name,
    class: class_name,
    methods: format_calls_architecture(methods_list , called_methods)
  }

  all_methods.concat(methods_list)

  all_dots << class_structure


end


for i in 0..(all_dots.length-1)

    file_path = files_list[i]
    file_name = get_file_name(file_path)

    class_structure = all_dots[i]
    puts "\n before \n"
    puts class_structure

    class_structure[:methods].each do |method|
        method[:called_methods].select! { |m| all_methods.include?(m.to_sym) }
    end

    puts "\n after \n"
    puts class_structure

    dot_structure = geDotFileObject(class_structure) 

    createDotFile(dot_structure , file_name)

    system("dot -Tsvg call_graph.dot -o #{file_name}.svg")
end
