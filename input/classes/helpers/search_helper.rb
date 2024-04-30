# frozen_string_literal: true

module SearchHelper
  #### Helper Method for Graph/Doc multisearch
  # params
  #
  # term : term for the search
  # user : the user who run the search / used to apply policies
  # filter : custom additional filter to apply, .. default to nil
  # => filter must be a hash with keys: [:graph, :document] which wrap a bool filter (the elasticsearch DSL bool filter)
  # options: custom options for the query .. like size, highlight, etc ... default to nil (see )
  # rubocop:disable Metrics/MethodLength
  def applicable_graph_doc_search(term, current_user, filter = {}, options = {})
    search = {
      dis_max: {
        tie_breaker: 0.7,
        boost: 1.2,
        queries: Graph.search_queries(term) | Document.search_queries(term)
      }
    }
    search_definition = {
      query: {
        bool: {
          filter: [
            {
              term: {
                customer_id: current_user.customer_id
              }
            },
            {
              indices: {
                indices: [Graph.index_name],
                query: Graph.applicable_filter(current_user, filter[:graph] || {}),
                no_match_query: Document.applicable_filter(current_user, filter[:document] || {})
              }
            }
          ],
          must: [
            term.blank? ? {} : search
          ]
        }
      }
    }

    search_definition.deep_merge!(options)

    Elasticsearch::Model.search(search_definition, [Graph, Document])
  end

  ### Multisearch for Groups and Users
  def actors_search(term, current_user)
    search_definition = {
      query: {
        bool: {
          filter: {
            bool: {
              must: [
                {
                  term: {
                    customer_id: current_user.customer_id
                  }
                },
                {
                  indices: {
                    indices: [User.index_name],
                    query: { bool: { must_not: [{ term: { deactivated: true } }] } },
                    no_match_query: {
                      indices: {
                        indices: [Role.index_name],
                        query: { bool: { must_not: [{ term: { deactivated: true } }] } },
                        no_match_query: :all
                      }
                    }
                  }
                }
              ]
            }
          },
          must: {
            dis_max: {
              tie_breaker: 0.7,
              boost: 1.2,
              queries: [
                {
                  multi_match: {
                    query: term,
                    fields: ["title", "title.raw^2", "full_name", "full_name.raw"],
                    boost: 10,
                    type: :best_fields
                  }
                },
                {
                  multi_match: {
                    query: term,
                    fields: ["email", "email.raw"],
                    boost: 5,
                    type: :best_fields
                  }
                },
                {
                  multi_match: {
                    query: term,
                    fields: ["function", "function.raw"],
                    boost: 2,
                    type: :best_fields
                  }
                }
              ]
            }
          }
        }
      },
      size: 10_000
    }

    Elasticsearch::Model.search(search_definition, [User, Role, Group])
  end

  #### Multi-search for Tree View which return Graph, Doc, Directory inside the current directory
  def tree_view_search(term, directory, current_user, options = {})
    search_definition = {
      query: {
        bool: {
          filter: {
            bool: {
              must: [
                {
                  term: {
                    customer_id: current_user.customer_id
                  }
                },
                {
                  indices: {
                    indices: [Graph.index_name],
                    query: Graph.policy_es_filter(current_user,
                                                  bool: { must: [{ term: { directory_id: directory.id } }] }),
                    no_match_query: {
                      indices: {
                        indices: [Document.index_name],
                        query: Document.policy_es_filter(current_user,
                                                         bool: { must: [{ term: { directory_id: directory.id } }] }),
                        no_match_query:
                          lambda { |dir|
                            return { term: { parent_id: dir.id } } unless dir.parent_id.nil?

                            return { term: { parent_id: current_user.customer.root_directory.id } }
                          }.call(directory)
                      }
                    }
                  }
                }
              ]
            }
          },
          must: {
            dis_max: {
              tie_breaker: 0.7,
              boost: 1.2,
              queries: [
                {
                  multi_match: {
                    query: term,
                    fields: ["name", "name.raw", "title", "title.raw"],
                    type: :most_fields,
                    boost: 10
                  }
                },
                {
                  multi_match: {
                    query: term,
                    fields: ["reference", "reference.raw"],
                    type: :best_fields,
                    boost: 5
                  }
                }
              ]
            }
          }
        }
      }
    }

    search_definition.deep_merge!(options)

    Elasticsearch::Model.search(search_definition, [Graph, Document, Directory])
  end
  # rubocop:enable Metrics/MethodLength
end
