# == Schema Information
#
# Table name: posts
#
#  id         :bigint(8)        not null, primary key
#  title      :string(255)
#  content    :text(65535)
#  created_at :datetime         not null
#  updated_at :datetime         not null
#


class Post < ApplicationRecord


  has_many :students

  include Elasticsearch::Model
  include Elasticsearch::Model::Callbacks

  # Define the Elasticsearch index configuration
  settings(index: { number_of_shards: 1 , number_of_replicas: 0 , max_ngram_diff: 15 }, analysis: SearchAnalyzer.analyzers) do
    mappings dynamic: 'false' do
      indexes :title, type: :text, analyzer: :partial_word_analyzer , index_options: 'offsets'
      indexes :content, type: :text, analyzer: 'english', index_options: 'offsets'

    end
  end

  def as_indexed_json(_options = {})
  as_json(only: %i[title content] 
)
  end

  def self.search_by_default(query)
    __elasticsearch__.search(
      {
        query: {
          match: {
            title: query
          }
        }
      }
    )
  end

  def self.import_to_es
    Post.__elasticsearch__.delete_index! if Post.__elasticsearch__.index_exists?
    Post.__elasticsearch__.client.indices.create \
    index: Post.index_name,
    body: {
      settings: Post.settings.to_hash,
      mappings: Post.mappings.to_hash
    }
    Post.import
  end

end
