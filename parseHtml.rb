require 'nokogiri'
require 'parser/current'

# Chemin vers le fichier HTML.erb
file_path = './input/index.html.erb'

# Charger le contenu du fichier HTML.erb
html_erb_code = File.read(file_path)

# Parser le contenu avec Nokogiri pour extraire l'AST HTML
html_ast = Nokogiri::HTML.parse(html_erb_code)

# Extraire les appels de méthode Ruby du fichier HTML.erb
method_calls = []

# Parcourir chaque balise script contenant du code Ruby

puts "#{html_ast.css('script')} =>=>"
html_ast.css('script').each do |script|
  # Extraire le code Ruby à partir de la balise script
  ruby_code = script.content.strip
  
  # Parser le code Ruby avec Parser
  ruby_ast = Parser::CurrentRuby.parse(ruby_code)

  puts "ruby ast =>"
  pp ruby_ast
  # Parcourir chaque nœud du code Ruby
  ruby_ast.each_node do |node|
    # Si c'est un appel de méthode
    puts "node => #{node}"
    if node.is_a?(Parser::AST::Node) && node.type == :send
      # Extraire le nom de la méthode appelée
      method_name = node.children[1]

      # Ajouter le nom de la méthode à la liste des appels de méthode
      method_calls << method_name
    end
  end
end


