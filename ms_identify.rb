
require 'parser/current'

require './helpers/Cluster.rb'

require './helpers/ASTExtractor'

require './helpers/DependencyGraph'

require './helpers/FilesAccess'

folder_path = "./input/classes"

folder_data_path = "./input/data"


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



def get_score_quality_of_ms(dependencies , clusters ,cluster , a = 1 , b = 0)
  ca = dependencies.get_intra_dependencies_of_ms(cluster)    
  ce = dependencies.get_inter_dependencies_of_ms(clusters , cluster) + 1.0e-10
  size = cluster.class_names.length
  data_cohesion = dependencies.get_data_cohesion_of_ms(cluster)
  # score = ( ca.to_f / ( ce ) / ( size * (size - 1) / 2   ) )
  score = (a * ca.to_f / ( ce + ca  ) ) + ( b * data_cohesion  )

  return score
end

def get_score_quality_of_all_ms(dependencies , clusters , cluster , alpha = 0.5 , beta =0.5)
  ca = dependencies.get_intra_dependencies_of_all_ms(clusters)    
  ce = dependencies.get_inter_dependencies_of_all_ms(clusters) + 1.0e-10
  data_cohesion = dependencies.get_data_cohesion_of_ms(cluster)
  score = ( alpha * ca.to_f / ( ce + ca ) ) + (beta * data_cohesion) 
  return score
end


def find_closest_pair(clusters , index , dependencies) 

  best_score = -Float::INFINITY
  best_clusters = nil
    clusters.combination(2) do |cluster1, cluster2|
      new_clusters = clusters.reject { |cluster| cluster == cluster1 || cluster == cluster2 }
      new_cluster = Cluster.new("Cluster#{index}" , cluster1.class_names + cluster2.class_names)
      new_clusters << new_cluster
      score = get_score_quality_of_all_ms(dependencies , new_clusters , new_cluster)
      if score > best_score
        best_score = score
        best_clusters = [cluster1 , cluster2]
      end
    end
    best_clusters
end

def herarchical_clusering(dependencies)
  sartifacts = @dependences.graph.keys  # Array of artifacts extracted from code
  s_clusters = []   # Array of clusters of artifacts
  dendro = []
  
  # Step 2: Create a cluster for each artifact
  sartifacts.each_with_index do |class_name, index|
    cluster_name = "Cluster#{index + 1}"  
    cluster = Cluster.new(cluster_name, [class_name])  
    s_clusters << cluster
  end

  dendro << s_clusters
  count = s_clusters.length
  
  # Step 3: Merge clusters until only one cluster remains
  while s_clusters.size > 1
    count +=1
    # Step 4: Find closest pair of clusters based on FQuality(MS)
    cluster1, cluster2 = find_closest_pair(s_clusters , count , dependencies)
    new_clusters = s_clusters.reject { |cluster| cluster == cluster1 || cluster == cluster2 }
    new_cluster = Cluster.new("Cluster#{count}" , cluster1.class_names + cluster2.class_names)
    new_clusters << new_cluster
    s_clusters = new_clusters
    dendro << s_clusters
  end
  
  return dendro
end


def get_children_of_cluster(dendro , cluster_parent)
  children = []
  index  = cluster_parent[:index] - 1
  find = false
  while (index >= 0  && find == false )
    clusters = dendro[index]
    clusters.combination(2) do |child1, child2|
      if (child1.class_names + child2.class_names == cluster_parent[:cluster].class_names)
        children = [{index: cluster_parent[:index] - 1 ,  cluster: child1 } , {index: cluster_parent[:index] - 1 , cluster: child2} ]
        find = true
        break  
      end
    end
    index = index - 1
  end

  children
end

def identify_msa_condidates(dependencies, dendro)
  stack_clusters = []
  stack_clusters.push({
      index: dendro.length - 1,
      cluster: dendro[dendro.length - 1][0]
  })

  msa = []

  while stack_clusters.size > 0
    cluster_parent = stack_clusters.pop

    if cluster_parent[:index] == 0 || cluster_parent[:cluster].class_names.length == 1
      msa << cluster_parent[:cluster]
    else
      child1, child2 = get_children_of_cluster(dendro , cluster_parent)
    
      s_new_clusters = [] 
      s_new_clusters << child1[:cluster] 
      s_new_clusters << child2[:cluster]
      s_old_clusters = [] 
      s_old_clusters << cluster_parent[:cluster]
      for i in 0..(stack_clusters.length-1)
          s_new_clusters << stack_clusters[i][:cluster]
          s_old_clusters << stack_clusters[i][:cluster]
      end

     if ( ( get_score_quality_of_all_ms(dependencies , s_new_clusters , child1[:cluster] ) + get_score_quality_of_all_ms(dependencies , s_new_clusters , child2[:cluster] )  ) / 2 >=  get_score_quality_of_all_ms(dependencies , s_old_clusters , cluster_parent[:cluster] ) )
        stack_clusters.push(child1)
        stack_clusters.push(child2)
      else
        msa << cluster_parent[:cluster]
      end
    end
  end

  msa
end

def get_classes_info(folder_path)

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
      methods: format_calls_architecture(methods_list , called_methods )  , 
      receivers: receivers
    }


    methods_list.each do |calling_method| 
      class_of_all_methods << class_name.to_s
    end

    all_methods.concat(methods_list)

    all_dots << class_structure

  end

  [all_dots , all_methods , class_of_all_methods]
end

def get_results(all_dots , all_methods , class_of_all_methods , data , microservice_file = "./output/microservices" )

      not_needed_methods = ['send' ,'new', 'initialize', 'find', 'save', 'update', 'delete', 'destroy', 'join',
    'split', 'sort', 'length', 'size', 'count', 'get', 'set', 'include', 'is_a']

    class_names = all_dots.map { |hash| hash[:class] }

    class_names = class_names.map(&:to_s)

    @dependences = DependencyGraph.new(class_names)


    for i in 0..(all_dots.length-1)

        class_structure = all_dots[i]

        class_name = class_structure[:class].to_s

        class_structure[:methods].each do |method|
          method[:called_methods].select! { |m| all_methods.include?(m) && !not_needed_methods.include?(m[:name].to_s)}
        end

      if (class_name.include?("Controller"))
        class_structure[:receivers].each do |receiver|
          if (data.include?(receiver.to_s))
            @dependences.add_data(class_name, singularize( receiver.to_s))
          end
        end
      end

        class_structure[:methods].each do |method|
            method[:called_methods].each do |called_method|
                indexes = []
                all_methods.each_with_index do |element, index|
                  indexes << index if element == called_method
                end
                indexes.each do |index|
                  class_of_called_method = class_of_all_methods[index] || ""
                  @dependences.add_dependency(class_name , class_of_called_method)
                end
                
            end
        end

    end
    dendro = herarchical_clusering(@dependences)

    msa = identify_msa_condidates(@dependences , dendro)

    depend = @dependences

    File.open(microservice_file + ".dot", "w") do |file|
      file.puts "digraph Microservices {" 
      # Iterate over each key-value pair in the hash
      msa.each do |microservice|
        # Add subgraph for microservice
        file.puts "  subgraph #{microservice.name}_microservice {"
  
        # Add nodes for classes
        microservice.class_names.each do |class_name|
          file.puts "    #{class_name};"
        end
  
        # Close the subgraph
        file.puts "  }"
      end
  
      # Close the dot file
      file.puts "}"
  
    end

    return [dendro , msa , depend ]
  
end
  
  

def msa_condidate_with_data_cohesion(n , depend , microservice_file = "./output/microservices")
  data_entity_counts = Hash.new(0)
  not_needed_data_entity = ["Color"]
  # Parcourir chaque microservice et compter le nombre d'occurrences de chaque data entity
  data_dependence = depend.data_count
  data_dependence.dup.each do |class_name, data_entities|
    data_entities.each do |data , count|
      if (!not_needed_data_entity.include?(data))
          data_entity_counts[data] += count
      end
    end
  end

  # Sélectionner les n data entities les plus utilisées
  top_data_entities = data_entity_counts.sort_by { |data_entity, count| -count }.take(n).to_h

  # selectioner les microservices
  microservices = Hash.new { |hash, key| hash[key] = [] } 
  data_dependence.each do |class_name, data_entity_count|
    most_used_data_entity =  "" 
    score = 0 ; 
    top_data_entities.each_key do |top_data| 
      if (data_entity_count[top_data] && data_entity_count[top_data] > score )
        score = data_entity_count[top_data]
        most_used_data_entity = top_data
      end
    end
    if (most_used_data_entity != "" ) 
      microservices[most_used_data_entity] << class_name
    end
    
  end
  
  File.open(microservice_file + ".dot", "w") do |file|
    file.puts "digraph Microservices {" 
    # Iterate over each key-value pair in the hash
    ms_num = 1
    microservices.each_key do |microservice|
      file.puts "  subgraph microservice_#{ms_num} {"
      ms_num = ms_num + 1

      microservices[microservice].each do |class_name|
        file.puts "    #{class_name};"
      end

      file.puts "  }"
    end

    file.puts "}"

  end
  return microservices 
end

def getClassesOfMs (depend , microservices ,  ms_classes_file = "./output/microservices_classes") 
  File.open(ms_classes_file + ".dot", "w") do |file|
    file.puts "digraph Microservices {" 
    # Iterate over each key-value pair in the hash
    ms_num = 1
    microservices.each_key do |microservice|
      file.puts "  subgraph microservice_#{ms_num} {"
      ms_num = ms_num + 1
      class_dependeces = []
      microservices[microservice].each do |class_name|
        file.puts "    #{class_name};"
        depend.graph[class_name].each do |class_name_depend, count|
          if (!class_name_depend.include?("Controller") && !class_dependeces.include?(class_name_depend))
            class_dependeces << class_name_depend
          end
        end
      end
      class_dependeces.each do |class_name_depend|
        file.puts "    #{class_name_depend};"
      end
      file.puts "  }"
    end
    file.puts "}"

  end

end



data = getDataEntity(folder_data_path)

all_dots ,  all_methods  , class_of_all_methods = get_classes_info(folder_path)

dendro , msa , depend = get_results(all_dots , all_methods , class_of_all_methods  , data)

microservices = msa_condidate_with_data_cohesion(8 , depend)

getClassesOfMs(depend,microservices)


puts "\n\ file done => ./output/microservice.dot"


















