
require 'parser/current'


folder_path = "./test"

not_needed_methods = ['send' ,'new', 'initialize', 'find', 'save', 'update', 'delete', 'destroy', 'join',
'split', 'sort', 'length', 'size', 'count', 'get', 'set', 'include', 'is_a']



class Cluster
  attr_accessor :name, :class_names

  def initialize(name, class_names)
    @name = name
    @class_names = class_names
  end
end


class DependencyGraph

    attr_reader :graph
    def initialize(classes)
      @graph = Hash.new { |hash, key| hash[key] = {} }
      classes.each do |class_name|
        @graph[class_name.to_s] = {}      
      end     
    end
  
    def add_dependency(class_name, dependent_class)
        if @graph[class_name][dependent_class] 
            @graph[class_name][dependent_class] += 1
        else 
            @graph[class_name][dependent_class] = 1
        end 
    end
  
    def get_dependencies_of_class(class_name)
      @graph[class_name]
    end

    def get_intra_dependencies(class_name) 
        @graph[class_name][class_name] || 0
    end

    def get_inter_dependencies_of_class(class_name) 
      count = 0
      @graph[class_name].each_value do |dependency_count|
        count += dependency_count
      end
      if (@graph[class_name][class_name]) 
          count = count - @graph[class_name][class_name]
      end
      count      
    end

    def get_intra_dependencies_of_ms(cluster)
      count = 0
      cluster.class_names.each do |class_name|
        @graph[class_name].each do |key, value|
            if (cluster.class_names.include?(key) && key != class_name)
              count += value
            end
        end
      end
      return count
    end

    def get_intra_dependencies_of_all_ms(clusters)
      count = 0
      clusters.each do |cluster| 
        count += get_intra_dependencies_of_ms(cluster)
      end
      return count
    end

    def get_inter_dependencies_of_ms(cluster) 
      count = 0
        cluster.class_names.each do |class_name_of_cluster| 
          @graph[class_name_of_cluster].each do |key, value|
            if (!cluster.class_names.include?(key) )
              count += value
            end
          end
        end
      return count
    end

    def get_inter_dependencies_of_all_ms(clusters) 
      count = 0
      clusters.each do |cluster| 
        count += get_inter_dependencies_of_ms(cluster)
      end
      return count
    end
  
    def print_dependencies(class_name)
        dependencies = get_dependencies(class_name)
        puts "Dependencies for #{class_name}:"
        dependencies.each do |dependent_class, dependency_count|
          puts "#{dependent_class}: #{dependency_count}"
        end
        puts "\n\n"
    end

    def print_all_dependencies
        @graph.each_key do |class_name|
          print_dependencies(class_name)
        end
      end

  end

  
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
        # recievers: recievers_list
      }
      calls_architecture << formatted_method
    end
  
    return calls_architecture
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

class_names = all_dots.map { |hash| hash[:class] }

class_names = class_names.map(&:to_s)

@dependences = DependencyGraph.new(class_names)


puts "\n\n\n dependecies => --------------------------------------- \n\n"
pp all_dots

for i in 0..(all_dots.length-1)

    class_structure = all_dots[i]

    class_name = class_structure[:class].to_s

    class_structure[:methods].each do |method|
        method[:called_methods].select! { |m| all_methods.include?(m.to_sym) && !not_needed_methods.include?(m.to_s) }
    end

    class_structure[:methods].each do |method|
        method[:called_methods].each do |called_method|
            class_of_called_method = class_of_all_methods[all_methods.index(called_method.to_sym)] || ""
            @dependences.add_dependency(class_name , class_of_called_method)
        end
    end

end

def get_score_quality_of_ms(dependencies , cluster)
  ca = dependencies.get_intra_dependencies_of_ms(cluster)    
  ce = dependencies.get_inter_dependencies_of_ms(cluster) + 1.0e-10
  size = cluster.class_names.length
  score = ca.to_f / ( ce ) / ( size * (size - 1) / 2   )
  #/ ( size * (size - 1) / 2   )
  return score
end

def get_score_quality_of_all_ms(dependencies , clusters)
  ca = dependencies.get_intra_dependencies_of_all_ms(clusters)    
  ce = dependencies.get_inter_dependencies_of_all_ms(clusters) + 1.0e-10
  # size = cluster.class_names.length
  score = ca.to_f / ( ce ) 
  #/ ( size * (size - 1) / 2   )
  return score
end

def find_closest_pair(clusters , index , dependencies) 

  best_score = -Float::INFINITY
  best_clusters = nil

    clusters.combination(2) do |cluster1, cluster2|
      new_clusters = clusters.reject { |cluster| cluster == cluster1 || cluster == cluster2 }
      new_cluster = Cluster.new("Cluster#{index}" , cluster1.class_names + cluster2.class_names)
      new_clusters << new_cluster
      score = get_score_quality_of_ms(dependencies , new_cluster)
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
    cluster_name = "Cluster#{index + 1}"  # Assigning names to clusters (e.g., Cluster1, Cluster2, etc.)
    cluster = Cluster.new(cluster_name, [class_name])  # Assuming Cluster is a class representing a cluster of artifacts
    s_clusters << cluster
  end

  dendro << s_clusters

  count = s_clusters.length
  
  # Step 3: Merge clusters until only one cluster remains
  while s_clusters.size > 1
    count +=1
    # Step 4: Find closest pair of clusters based on FQuality(MS)
    cluster1, cluster2 = find_closest_pair(s_clusters , count , dependencies)
  
    # Step 5: Merge the closest pair into a new cluster
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

    if cluster_parent[:index] == 0
      msa << cluster_parent[:cluster]
    else
      child1, child2 = get_children_of_cluster(dendro , cluster_parent)

     if ( ( get_score_quality_of_ms(dependencies , child1[:cluster]) + get_score_quality_of_ms(dependencies , child2[:cluster]) ) / 2) > get_score_quality_of_ms(dependencies , cluster_parent[:cluster])
        stack_clusters.push(child1)
        stack_clusters.push(child2)
      else
        msa << cluster_parent[:cluster]
      end
    end
  end

  msa
end


puts "\n\n\n results => ----------------------------------\n\n"



dendro = herarchical_clusering(@dependences)

pp dendro

msa = identify_msa_condidates(@dependences , dendro)



puts "\n\n\n msa condidats => ---------------------------------------\n\n"

pp msa










