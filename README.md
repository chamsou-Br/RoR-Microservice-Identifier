# Microservice Identification Tool

## Introduction

This application identifies microservices within a monolithic application developed with Ruby on Rails. The identification process follows four steps:

1. **Class Artifact Extraction**: Extracts class artifacts from the object-oriented source code of the monolithic application. These artifacts are categorized into different architectural layers (business and data access).
2. **Dependency Extraction**: Extracts vertical dependencies between categorized artifacts.
3. **Clustering Algorithm**: Uses an automatic clustering algorithm to identify microservice candidates from the extracted layered architecture artifacts.

## Classes and Their Roles

The core functionality is defined in the `tools` folder, with the following classes:

### ClassNode

- Represents a node of the AST corresponding to a class in the source code.
- Attributes:
  - `class_name`: The name of the class.
  - `module_name`: The name of the module.
  - `methods_defined`: List of methods defined in this class.
  - `methods_called`: List of methods called.
  - `data_entities`: Data entities used by this class.
- These details are extracted from the AST during traversal.

### MethodNode

- Represents a node of the AST corresponding to a method in the source code.
- Attributes:
  - `method_name`: The name of the method.
  - `parameters_count`: Number of parameters.
  - `methods_called`: Methods called by this method.

### ASTParserClass

- Responsible for syntactic analysis of the source code to generate the AST for each class using a language-specific parsing library (e.g., `ast` for Python or `parser` for Ruby).
- For each class file, it creates an instance of `ASTExtractor` with the corresponding AST.

### ASTExtractor

- Extracts relevant information from the AST of a specific class.
- Methods to retrieve:
  - Class name
  - Defined methods
  - Called methods
  - Data entities
  - Class module
  - Number of arguments for each method
- Traverses the AST and uses matching patterns to identify different elements.

### DependencyAnalyzer

- Analyzes dependencies between classes based on the extracted AST information.
- Traverses nodes representing classes and methods to identify method calls between classes and data entities used by each class.
- Establishes dependency links between classes based on these calls and data accesses.
- Evaluates the quality of a cluster (microservice candidate) by examining its internal cohesion and external coupling.
- A high-quality cluster will have strong cohesion (classes are tightly related through structure and data usage) and low coupling (minimal dependencies between clusters).

### ClusterEngine

- Implements a hierarchical clustering algorithm for detecting potential microservices.
- Based on class dependencies identified by the `DependencyAnalyzer`.
- Groups strongly interconnected classes sharing the same data entities into clusters.

### Cluster

- Represents a cluster of classes identified by the hierarchical clustering algorithm.
- Contains:
  - `cluster_id`: The identifier of the cluster (corresponding microservice candidate).
  - `classes_list`: List of classes belonging to this cluster.

### FilesManager

- Manages reading the source code of the monolithic application and optionally writing generated files for microservice candidates.
- Used to load source files into the `ASTParser` and write the results of hierarchical clustering (microservice candidates) into output files.

## Conclusion

This tool simplifies the process of identifying potential microservices within a monolithic Ruby on Rails application by systematically extracting class artifacts, analyzing dependencies, and applying a clustering algorithm. The identified microservice candidates can help in transitioning from a monolithic architecture to a more scalable and maintainable microservice architecture.
