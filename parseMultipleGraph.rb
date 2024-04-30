require 'parser/current'
require './helpers/ASTExtractor'
require "./helpers/FilesAccess"

folder_path = "./input/controllers"



def format_calls_architecture(methods_list , called_methods)
  calls_architecture = []

  methods_list.each do |calling_method|
    called_methods_list = called_methods[calling_method[:name]] || []
    formatted_method = {
      calling_method: calling_method[:name].to_s,
      called_methods: called_methods_list,
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
                  if (called_method[:name].include?("?"))
                    called_method[:name].sub!("?", "")
                      dot_line = calling_method + " -> " + called_method[:name] + ";"
                  elsif (called_method[:name].include?("!"))
                    called_method[:name].sub!("!", "")
                      dot_line = calling_method + " -> " + called_method[:name] + ";"
                  else
                      dot_line = calling_method + " -> " + called_method[:name] + ";"
                  end
                  desired_table.push(dot_line)
              end
          end
        end
  
      end
  
    return desired_table
  end


  def createDotFile(dot_structure, file_name)
    dot_file_path = './output/call_graph.dot'
    File.open("./output/call_graph.dot", "w") do |file|
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
  
    dot_file_content = File.read(dot_file_path)
    unique_lines = dot_file_content.lines.uniq 
    File.write(dot_file_path, unique_lines.join)
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

  File.write('./output/parse_ast.txt', ast)


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


    class_structure[:methods].each do |method|
        method[:called_methods].select! { |m| all_methods.include?(m) }
    end


    dot_structure = geDotFileObject(class_structure) 

    createDotFile(dot_structure , file_name)

    puts "\n\ file done => #{file_name}"

    system("dot -Tsvg ./output/call_graph.dot -o ./output/#{file_name}.svg")
end
