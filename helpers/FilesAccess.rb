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