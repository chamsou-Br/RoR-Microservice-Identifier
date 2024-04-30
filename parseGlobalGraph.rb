
require 'parser/current'
require './helpers/ASTExtractor'
require './helpers/FilesAccess'
require './helpers/DotFile'

folder_path = "./input/classes"
folder_data_path = "./input/data"


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
  
  def singularize(word)
    case word
    when /s$/
      # Remove the 's' at the end and lowercase the first letter
      word.chomp('s').capitalize
    else
      # Add more transformation rules if needed
      word
    end
  end


def getDataEntity(folder_data_path)
  
  files_list = getFilesFromFolder(folder_data_path) #return paths of all files inside a folder in addition to its children folders
  all_data = []

  for i in 0..(files_list.length-1)
      file_path = files_list[i]
      file_name = get_file_name(file_path) #return filename from the file path    
      source_code = File.read(files_list[i])    
      buffer = Parser::Source::Buffer.new(files_list[i]).tap do |buffer| 
            buffer.source = source_code
      end
    
      parser = Parser::CurrentRuby.new
    
      ast = parser.parse(buffer)

      extractor = ASTExtractor.new
      extractor.process(ast)

      all_data << extractor.class_name.to_s

      all_data << extractor.class_name.downcase.to_s + "s"


  end
  all_data

end

def get_dependencies(folder_path)

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
    
      File.write('./output/parse_ast.txt', ast)

      class_name, methods_list, called_methods , module_name , receivers , method  = get_class_info(ast)

      methods_name = methods_list.map { |m| m[:name].to_sym}

    class_structure = {
      module: module_name,
      class: class_name,
      methods: format_calls_architecture(methods_list , called_methods )  , 
      receivers: receivers
    }


    methods_name.each do |calling_method| 
      class_of_all_methods << class_name.to_s
    end

    all_methods.concat(methods_list)

    all_dots << class_structure

  end

  [all_dots , all_methods , class_of_all_methods]
end


def get_results(folder_path , all_dots , all_methods , class_of_all_methods , data , dot_file_path = './output/call_graph' , dot_file_path_data = "./output/call_graph_data")

  
  files_list = getFilesFromFolder(folder_path)

  dot_file_content = []

  dot_file_data_content = []
  
  for i in 0..(all_dots.length-1)
  
  
      file_path = files_list[i]
      file_name = get_file_name(file_path)
  
      class_structure = all_dots[i]

      class_structure[:methods].each do |method|
          method[:called_methods].select! { |m| all_methods.include?(m) }
      end

      dot_structure = geDotFileObject(class_structure , all_methods , class_of_all_methods) 

      dot_structure_data = geDotFileObjectForData(class_structure , data);

      dot_file_content << dot_structure

      dot_file_data_content << dot_structure_data
  
  end
  
  createDotFile(dot_file_content , "#{dot_file_path}.dot" , true)

  createDotFile(dot_file_data_content , "#{dot_file_path_data}.dot")
  
  system("dot -Tsvg #{dot_file_path}.dot -o #{dot_file_path}.svg")
  system("dot -Tsvg #{dot_file_path_data}.dot -o #{dot_file_path_data}.svg")

  puts "\n\ file done => #{dot_file_path}.svg " 
  puts "\n\ file done => #{dot_file_path_data}.svg"
  
end
  
  
  
all_dots ,  all_methods  , class_of_all_methods = get_dependencies(folder_path)

data = getDataEntity(folder_data_path)


get_results(folder_path , all_dots , all_methods , class_of_all_methods , data)

