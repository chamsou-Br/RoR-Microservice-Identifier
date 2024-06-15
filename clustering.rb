require "./tools/FilesManager"
require "./tools/ASTParserClass"
require "./tools/ClassNode"
require "./tools/MethodNode"
require "./tools/ASTExtractor"
require "./tools/ClassTypeEnum"
require "./tools/helpers"
require "./tools/DependencyAnalyzer"
require "./tools/ClusterEngine"
require "./tools/Cluster"
require 'parser/current'


puts "\n----------------------------------------------------"
puts   "|                    Loading ...                    |"
puts   "----------------------------------------------------"

fileManager = FilesManager.new()

classNodes = fileManager.generate_ast_parsers("./input/classes")

dataNodes = fileManager.generate_ast_data_parser("./input/data")

@dependencies = DependencyAnalyzer.new(classNodes , dataNodes)

ClusterEngine.get_microservices(@dependencies , 0.2 , 0.8)

puts   "                       ||                           "
puts   "----------------------------------------------------"
puts   "|          Done   => ./output/clusters              |"
puts   "----------------------------------------------------\n"




