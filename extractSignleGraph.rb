require 'ripper'
require "pp"

### RESULT SO FAR
### in this version, I am  retrieving right the class, the calling methods names and also the list of called methods
### I am organizing the result in a table that I after use it for making a dotfile and generate
### the call graph

# ruby_file = './global_files/actors_controller.rb'
# source_code = File.read(ruby_file)
# # Extracting the AST
source_code =  File.read("./class.rb")

ast = Ripper.sexp(source_code)

#Copying AST in two txt files
File.write('one_line_ast.txt', ast)
# File.open('_multiple_line_ast.txt', 'w') do |file|
#   PP.pp(ast, file)
# end



# # Read AST
ast_tree = File.read("one_line_ast.txt")

#Get class name from ruby ast file
def getClassName (ast_tree, keyword="class")
  #initiate the class name
  class_name = ""

  #Point where the classname starts
  starting_index =  ast_tree.index(keyword) + 31

  ## TO DO: this helps to check if we have a class do ... if not we retrieve the module name
  # if (ast_tree.index(keyword))
  #   starting_index =  ast_tree.index(keyword) + 31
  # end

  #iterate the AST Tree from classname index until we find a => "
  ast_tree[starting_index..-1].each_char do |char|
    break if char == '"'
    class_name += char
  end

  return class_name
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

  # this block doesnt have value in single call_graph ------------------------------------------------
  
  called_methods_code = extract_methods(actual_method, keyword1, nb_methods)

  # counting and returning number of arguments for called methods
  arguments_number = []
  for i in 0..(called_methods_code.length-1)
    argument_count = count_arguments(eval(called_methods_code[i])) 
    arguments_number.push(argument_count)
  end

   # this block doesnt have value in single call_graph ----------------------------------------------------

  # getting the names of all called methods by a calling method
  called_methods = getMethodsNames(methods_list[method_number], keyword3, keyword2)


  # structuring my data
  return calls_architecture = {
    calling_method: method_name,
    called_methods: called_methods
  }
end




# pp methods_with_calls


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
def createDotFile(dot_structure)
  File.open("call_graph.dot", "w") do |file|
      file.puts 'digraph CallGraph {'
      dot_structure.each do |entry|
          file.puts entry
      end
      file.puts '}'
  end
end
#------- MANAGE DOTFILE -------#



#------- store methods list in a variable -------#



methods_list = getMethodsList(ast_tree)


methods_with_calls =[]
for i in 0..methods_list.length-1
    methods_with_calls << getMethodWithCalls(i, methods_list)
end


#------- CALLS -------#
getClassName(ast_tree)
getMethodsList(ast_tree)

class_structure = {
  class: getClassName(ast_tree),
  methods: methods_with_calls
}

puts class_structure 
puts "end clas structure"
dot_structure = geDotFileObject(class_structure) # store table to use it to create the dot file

createDotFile(dot_structure)

system("dot -Tsvg call_graph.dot -o call_graph.svg")


