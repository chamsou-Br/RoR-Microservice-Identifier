

def get_call_graph(ASTs)
    for i in 0..(ASTs.length-1) 
        class_structure = ASTs[i]
        desired_table = []
        class_name = class_structure[:class]
        class_structure[:methods].each do |method|
            called_methods = method[:called_methods]
            calling_method = method[:calling_method] 
            called_methods.each do |called_method|
                class_of_called_method = get_class_of_all_methods(called_method)
                dot_line = class_name.to_s +  " -> " + class_of_called_method +  ";"
                desired_table.push(dot_line)
            end
        end
        return desired_table
    end
end


class DependencyGraph

    attr_reader :graph , :data ,  :data_count
    
  
    def add_dependency(class_name, dependent_class)
        if @graph[class_name][dependent_class] 
            @graph[class_name][dependent_class] += 1
        else 
            @graph[class_name][dependent_class] = 1
        end 
    end


    def get_intra_dependencies_of_all_ms(clusters)
      count = 0
      clusters.each do |cluster| 
        count += get_intra_dependencies_of_ms(cluster)
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
      f_data 
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

