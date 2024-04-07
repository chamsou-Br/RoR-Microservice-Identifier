class DependencyGraph

    attr_reader :graph , :data ,  :data_count
    def initialize(classes)
      @graph = Hash.new { |hash, key| hash[key] = {} }
      @data = Hash.new { |hash, key| hash[key] = {} } 
      @data_count = Hash.new { |hash, key| hash[key] = {} } 
      classes.each do |class_name|
        @graph[class_name.to_s] = {}  
        @data[class_name.to_s] = []    
        @data_count[class_name.to_s] = {}
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

    def get_inter_dependencies_of_ms(clusters , new_cluster) 
      count = 0
      clusters.each do |cluster|
          cluster.class_names.each do |class_name_of_cluster| 
            @graph[class_name_of_cluster].each do |key, value|
              if ( (!new_cluster.class_names.include?(class_name_of_cluster) && new_cluster.class_names.include?(key) ) || (new_cluster.class_names.include?(class_name_of_cluster) && !new_cluster.class_names.include?(key) ) )
                count += value
              end
            end
          end
      end
      return count
    end

    def get_inter_dependencies_of_all_ms(clusters) 
      count = 0
      clusters.each do |cluster|
        cluster.class_names.each do |class_name_of_cluster| 
          @graph[class_name_of_cluster].each do |key, value|
            if (!cluster.class_names.include?(key))
              count += value
            end
          end
        end
    end
      return count
    end

    def get_data_cohesion_of_ms(cluster)
      f_data = 0
      cluster.class_names.combination(2) do |class1 , class2| 
        f_sim_data = ( @data[class1] & @data[class2] ).size / ( (@data[class1] | @data[class2] ).size  + 1.0e-10 )
        f_data += f_sim_data
      end
      f_data = f_data / ( cluster.class_names.size * (cluster.class_names.size - 1 ) / 2  + 1.0e-10)
      # if (f_data != 0 )
      #   puts "\n\n cluster #{cluster.class_names} => #{f_data}"
      # end
      f_data 
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

    def add_data(class_name , data_entity)
      if (!@data[class_name].include?(data_entity)) 
          @data[class_name] << data_entity
      end
      if @data_count[class_name][data_entity] 
        @data_count[class_name][data_entity] += 1
      else 
        @data_count[class_name][data_entity] = 1
      end 
    end

  end
