class ExportController < ApplicationController

  skip_before_action :authenticate_user!, only: [:graph, :document, :resource, :user, :role]

  before_action :authenticate_by_email_and_password

  def authenticate_by_email_and_password
    email = params[:email]
    password = params[:password]

    user = User.find_by(email: email)

    if user && user.valid_password?(password)
      @current_user = user
    else
      render json: { error: 'Unauthorized' }, status: :unauthorized
    end
  end



    def graph
      # Implement the logic for /api/export/graph
      keys, special_keys = Graph.default_export_keys(customer: current_customer, host: host, request: request)
      data = Graph.export_data(current_user.customer.graphs, keys, special_keys ,  "activerecord.attributes.graph")
      render json: { data: data }
    end

    def document
      keys, special_keys = Document.default_export_keys(customer: current_customer, host: host, request: request)
      data = Document.export_data(current_user.customer.documents, keys, special_keys ,  "activerecord.attributes.document")
      render json: { data: data }
    end

    def resource
      # Implement the logic for /api/export/resosurces
      keys, special_keys = Resource.default_export_keys
      data = Resource.export_data(current_user.customer.resources, keys, special_keys ,  "resources.csv.columns")
      render json: { data: data }
    end
  
    def user
      puts "dsfkln =>" 
      puts @current_user
      keys, special_keys = User.default_export_keys
      data = User.export_data(current_user.customer.users, keys, special_keys , 'roles.csv.columns')
      render json: { data: data }
    end

    def role
        keys, special_keys = Role.default_export_keys
        data = Role.export_data(current_user.customer.roles, keys, special_keys)
        render json: { data: data}
      end
  end