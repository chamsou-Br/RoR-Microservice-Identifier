def geDotFileObjectForData(structure,data)
    desired_table = []
    dot_line = "" #each line of the dot file
    class_name = structure[:class]
    desired_table << "subgraph cluster_#{class_name} {"
    desired_table <<  "\tlabel=\"#{class_name}\";"
    data_used = []
    structure[:receivers].each do |receiver| 
      if (data.include?(receiver.to_s) && !data_used.include?(receiver.to_s))
        data_used << receiver.to_s
      end
    end
    data_used.each_with_index do | entity , index |
      right_side = "#{singularize(entity)}_#{class_name.to_s}_#{index}"
      dot_line = class_name.to_s + " -> " + right_side + ";"
      desired_table.push(dot_line)
      desired_table.push("#{class_name.to_s} [shape=box, style=filled, fillcolor=lightblue  , color=white];")
      desired_table.push("#{right_side} [shape=circle, style=filled , fillcolor=lightgreen , label=#{singularize(entity)} , width=1.5, height=0.5 , color=white]; ")
    end
    desired_table << "}"
    return desired_table
  end
#------- MANAGE DOTFILE -------#
# create a table with a dot file structure by taking the calling methods
# in addition to called methods and add "-> & ;""
def geDotFileObject(structure,all_methods,class_of_all_methods , variables = nil , multi = false)
    desired_table = []
    dot_line = "" #each line of the dot file
    class_name = structure[:class]
  
    # predefined methods excluded from the call graph
    # not_needed_methods = []
    not_needed_methods = ['send', 'create' ,'new', 'initialize', 'find', 'save', 'update', 'delete', 'destroy', 'join',
                          'split', 'sort', 'length', 'size', 'count', 'get', 'set', 'include', 'is_a',"destroy","resource"]

    structure[:methods].each do |method|
        called_methods = method[:called_methods]
        calling_method = method[:calling_method] 
  
  
          if (!method[:called_methods].empty?)
              called_methods.each do |called_method|

                  called = {name: called_method[:name] , num_args: called_method[:num_args]}
                  reciever = called_method[:reciever]
                  indexes = []
                  isDetected = false
                  if (reciever && reciever != class_name ) 
                    if (class_of_all_methods.include?(reciever))
                      indexes << reciever.capitalize
                      isDetected = true
                    elsif variables 
                      results = []
                      results = variables[calling_method].select { |item| item[:name] == reciever } if variables[calling_method]
                      results += variables["initialize"].select { |item| item[:name] == reciever } if variables["initialize"]
                      if (results.length > 0)
                        isDetected = true
                        results.each do |res|
                          indexes << res[:value]
                        end
                      end
                    end
                  end

                  if isDetected == false
                    all_methods.each_with_index do |element, index|
                      indexes << class_of_all_methods[index] || "" if element == called 
                    end
                  end

                indexes.each do |class_of_called_method|    
                  if (( class_of_called_method.to_s != class_name.to_s || multi == true ) && !not_needed_methods.include?(called_method[:name]) && ( (reciever != "self" && reciever != class_name) || multi == true ))
                    input =  class_name.to_s 
                    output = class_of_called_method 
                    input += "_" + calling_method + "_" if multi == true
                    output += "_" + called[:name] + "_" if multi == true
                    dot_line = input +  " -> " + output + ";"
                    desired_table.push(dot_line)
                    desired_table.push("#{input} [shape=box, style=filled, fillcolor=lightblue  , color=white];")
                    desired_table.push("#{output} [shape=box, style=filled, fillcolor=lightblue  , color=white];")
                end
              end
              end
          end
        end
  
    return desired_table
  end

    # copy content of the table into the dot file
def createDotFile(dot_structure, file_name , unique = false)

    dot_file_path = file_name
  
    File.open(dot_file_path, "w") do |file|
      file.puts 'digraph CallGraph {'
      file.puts 'ranksep=5;'
      file.puts 'nodesep=0.5;'
      file.puts "node [fontname=Arial];"
      file.puts "edge [fontname=Arial];"
      dot_structure.each do |entry|
        file.puts entry
      end
      file.puts '}'
    end
  
    if (unique == true )
      dot_file_content = File.read(dot_file_path)
      unique_lines = dot_file_content.lines.uniq 
      File.write(dot_file_path, unique_lines.join)
    end
  end
