# RoR-callGraph-generator

Welcome to the Ruby on Rails call graph generator library. This library includes multiple scripts that allows you to generate a call graph at different levels "One class", "Multiple classes" and "Global" level.

## How it works

The generation of our call graphs is based on the static analysis, by generating the AST (Abstract Syntax Tree), we can perform a static analysis to extract our data and then transform this data into a visual using GraphViz library.

## Installation of required gems

- `gem install ripper` : This library allows us to extract and manipulate the AST (Abstract Syntax Tree) of Ruby files. 
- `gem install pp` : This is a basic Ruby library that allows us to print data into the console. 
- `gem install graphviz` : We used GraphViz library to generate the final output of our call graphs, it allowed us to generate the result in different formats and also manipulate our result for better visualization. 

## Available Features

### Extract a call graph of a specific file

To extract the call graph for a specific class, you can use the `extractSignleGraph.rb` file, to insure a correct result make sure to:
1. Replace the `ruby_file` variable with the actual path of your ruby file.

### Extract a call graph of multiple files at once

To extract the call graph for for multiple files at once, you can use the `extractMultipleGraphs.rb` file, to insure a correct result make sure to:
1. Gather all your files in a global folder and name it `global_files`, this folder may have other nested folders. (Check our example).
2. Clone `global_files` folder.
3. Change the name of the cloned folder to `callgraphs`. This new folder will contain the generated graphs as a result.
4. For a better result, make sure to delete all classes and files inside the result folder and leave only the folders structure. (Check our example).

The generated graph calls will placed in the result folder in the same placement as their original classes were located. (Test our example)

### Extract the global call graph of a RoR application or related files

To extract the call graph for a specific class, you can use the `extractSignleGraph.rb` file, to insure a correct result make sure to:

1. Change the `folder_path` variable in line 17 with the root folder of your project.
  This script will generate one svg call graph named `global_callGraph.svg`

## Considerations
- During generation of call graphs, a dot file may be created, you can ignore this file or delete it after the script is completely runed.
- In the second script, you should add into the result folder a folder with the exact name as your root folder. This folder will contain the call graphs for files from the root file.

## Output manipulation
As already mentioned, we used the GraphViz library to generate the visual call graph, so using features of the library you can manipulate your output, here are some common possible actions:
- Change the output format from svg to other supported formats.
- Change the size and margins between classes
In the `extactGlobalGraph.rb` We implemented a method to highlight specific classes with any desired color. To do so try to change the `focus_class` or `focus_method`

## Contact

For any questions or support, feel free to contact us at abdelouadoud.mahdaoui@gmail.com. We hope you find this tool helpful and welcome your contributions and feedback!
