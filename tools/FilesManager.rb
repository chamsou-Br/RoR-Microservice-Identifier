

class FilesManager

    def generate_ast_parsers(folder_path)

        files_list = getFilesFromFolder(folder_path) 

        classes = []

        for i in 0..(files_list.length-1)

            file_path = files_list[i]
            file_name = get_file_name(file_path) #return filename from the file path
            
            source_code = File.read(files_list[i])
            
            astParserClass = ASTParserClass.new(file_path , source_code , ClassType::ClassController)

            File.write('./output/parse_ast.txt', astParserClass.get_ast)
    
            classes << astParserClass.get_class_info

        end
        
        classes
    end

    def generate_ast_data_parser(folder_data_path)

        files_list = getFilesFromFolder(folder_data_path) #return paths of all files inside a folder in addition to its children folders
        dataNodes = []
      
        for i in 0..(files_list.length-1)

            file_path = files_list[i]

            source_code = File.read(files_list[i])    

            astParserClass = ASTParserClass.new(file_path , source_code , ClassType::DataEntity)

            dataNodes << astParserClass.get_class_info
      
        end

        dataNodes

    end

    def generate_single_ast_parsers(file_path)

        source_code = File.read(file_path) 
        astParserClass = ASTParserClass.new(file_path , source_code , ClassType::ClassController)

        File.write('parse_ast.txt', astParserClass.get_ast)

        classNode = astParserClass.get_class_info

        classNode
        
    end



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

end