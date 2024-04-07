require 'ripper'
require "pp"

# RESULT SO FAR
# extracted the call graph for multiple call graphs

# DONE:
# fixed the classname & module issue and added the module into the returned object
# fixed the repeated links

# TODO:
# fix the nested folders issue
# fix the ".." for calling methods inside other methods, example in controllers/improver/indicators_controller.rb


folder_path = "./global_files"

# Read AST
ast_tree = ""


# count number of files inside the folder (which is the number of iteration for the call graph)
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



#Get class name from ruby ast file
def getClassName(ast_tree, keyword = ":class")
  starting_index = ast_tree.index(keyword)

  if starting_index
    starting_index = ast_tree.index('"', starting_index) + 1
    class_name = ast_tree[starting_index..-1].each_char.take_while { |char| char != '"' }.join
  else
    class_name = "no classes"
  end

  class_name
end

def getModuleName (ast_tree, keyword=":module")
  #initiate the module name
  module_name = ""
  starting_index = ast_tree.index(keyword)

  #Point where the modulename starts
  if !(starting_index.nil?)
    starting_index =  ast_tree.index(keyword) + 33
    ast_tree[starting_index..-1].each_char do |char|
      break if char == '"'
      module_name += char
    end
  else
    module_name = "no modules"
  end

  return module_name
end

#------- Get list of methods -------#
def getMethodsList(ast_tree, keyword="[:def")
  methods_list = []
  nb_methods =  ast_tree.scan(/(?=#{Regexp.escape(keyword)})/).count

  for n in 1..nb_methods
    #initiation of variables
    starting_index = ast_tree.index(keyword)
    nb_brackets = 0
    current_method_code = ""

    # loop from start of the method until end
    loop do
      ast_tree[starting_index]
      if ast_tree[starting_index] == "["
        nb_brackets += 1
      elsif ast_tree[starting_index] == "]"
        nb_brackets -= 1
      end
      current_method_code += ast_tree[starting_index]
      starting_index += 1
      break if nb_brackets == 0
    end

    #writing method in the methods content table
    methods_list[n-1] = current_method_code

    #delete the added method because we are searching always for the first "def" we find
    ast_tree = ast_tree.sub(keyword, "")
  end

  return methods_list
end





#------- REUSSABLE METHODS -------#
def extract_methods(actual_method, keyword, nb_methods)
  called_methods_list = []

  nb_methods.times do
    starting_index = actual_method.index(keyword)
    nb_brackets = 0
    current_method_code = ""

    loop do
      char = actual_method[starting_index]

      if char == "["
        nb_brackets += 1
      elsif char == "]"
        nb_brackets -= 1
      end

      current_method_code += char
      starting_index += 1

      break if nb_brackets == 0
    end

    called_methods_list.push(current_method_code)

    actual_method = actual_method.sub(keyword, "")
  end
  return called_methods_list
end

# count the number of arguments for each called method within a calling method
def count_arguments(method)
  return 0 unless method.is_a?(Array)

  if method[0] == :args_add_block
    arguments = method[1].size
    return arguments
  else
    method.inject(0) { |count, node| count + count_arguments(node) }
  end
end

# get names of all called methods within a calling method
def getMethodsNames(calling_method, keyword1, keyword2)
  methods_names = []
  method_name = ""
  while calling_method.include?(keyword2)
    starting_index =  calling_method.index(keyword2)
    (starting_index).downto(0) do |i|
      if calling_method[i-5..i] === keyword1
        starting_index = i + 4
        method_name = calling_method[starting_index..-1][/^[^"]+/]
        calling_method = calling_method.sub(keyword2, '')
        break
      end
    end
    methods_names.push(method_name)
  end
  return methods_names
end
#------- REUSSABLE METHODS -------#


#------- Get
def getMethodWithCalls(method_number, methods_list, keyword1="[:method_add_arg", keyword2="arg_paren", keyword3 = '@ident')
  method_name = ""

  #--- Retieve the calling method name ---#
  method_name = methods_list[method_number][18..].partition("\"").first


  #--- get content of called methods ---#
  actual_method = methods_list[method_number]
  nb_methods =  actual_method.scan(/(?=#{Regexp.escape(keyword1)})/).count
  called_methods_code = extract_methods(actual_method, keyword1, nb_methods)

  # counting and returning number of arguments for called methods
  arguments_number = []
  for i in 0..(called_methods_code.length-1)
    argument_count = count_arguments(eval(called_methods_code[i])) # Evaluating the provided code as Ruby data structure
    arguments_number.push(argument_count)
  end

  # getting the names of all called methods by a calling method
  called_methods = getMethodsNames(methods_list[method_number], keyword3, keyword2)

  # structuring my data
  return calls_architecture = {
    calling_method: method_name,
    called_methods: called_methods
  }
end




#------- MANAGE DOTFILE -------#
# create a table with a dot file structure by taking the calling methods
# in addition to called methods and add "-> & ;""
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

# copy content of the table into the dot file
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
  unique_lines = dot_file_content.lines.uniq # Remove repeated lines
  File.write("call_graph.dot", unique_lines.join) # Write the updated content back to the dot file
end
#------- MANAGE DOTFILE -------#







files_list = getFilesFromFolder(folder_path) #return paths of all files inside a folder in addition to its children folders

for i in 0..(files_list.length-1)
  # File.open('_multiple_line_ast.txt', 'w') do |file|
  #   PP.pp(ast, file)
  # end

  #------- CALLS -------#
  source_code = ""

  file_path = files_list[i]
  file_name = get_file_name(file_path) #return filename from the file path
  pp file_name

  source_code = File.read(files_list[i])

  ast = Ripper.sexp(source_code)


  #Copying AST in two txt files
  File.write('one_line_ast.txt', ast)
  ast_tree = File.read("one_line_ast.txt")

  #------- store methods list in a variable -------#
  methods_list = getMethodsList(ast_tree)

  methods_with_calls =[]
  for i in 0..methods_list.length-1
      methods_with_calls << getMethodWithCalls(i, methods_list)
  end

  getMethodsList(ast_tree)
  pp getClassName(ast_tree)
  pp "___________"
  class_structure = {
    module: getModuleName(ast_tree),
    class: getClassName(ast_tree),
    methods: methods_with_calls
  }

  puts class_structure 
  puts "\n end \n"

  dot_structure = geDotFileObject(class_structure) # store table to use it to create the dot file

  createDotFile(dot_structure, file_name)
  system("dot -Tsvg call_graph.dot -o #{file_name}.svg")
end
