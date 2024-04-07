# frozen_string_literal: true

class UsersController < ApplicationController
  include ListableUser
  include UsersHelper

  def index

    respond_to do |format|
      format.html {}
      format.json { render_list "index", :list_index_definition, tags: :groups }

      format.csv do
        users = current_user.customer.users
        keys, special_keys = User.default_export_keys
        send_data User.export_csv(users, keys, special_keys),
                  filename: generate_file_name("csv")
      end
      format.xls do
        @users = current_user.customer.users
        filename = generate_file_name("xls")
        headers["Content-Disposition"] = "attachment; filename=\"#{filename}\""
      end
    end
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def create_random
    return unless Rails.env.development?

    require "net/http"
    # @type [User]
    base_user = current_customer.users_list(false, false).first.dup
    @results = []
    @number = params[:number].to_i || 1000
    @count = 0
    @created_count = 0
    times = (@number / 200).floor
    (0..times).each do |i|
      last = i == times ? @number % 200 : -1
      break if last.zero?

      url = URI.parse("http://api.randomuser.me/?results=#{last > -1 ? last : 200}&key=HNWS-FZN8-DYUG-ZC6G")
      req = Net::HTTP::Get.new(url.to_s)
      res = Net::HTTP.start(url.host, url.port) do |http|
        puts "round ##{i + 1} : call #{url}"
        http.request(req)
      end
      JSON.parse(res.body).each do |users|
        users[1].each_with_index do |user, j|
          @count += 1
          dup = base_user.dup
          dup.lastname = user["user"]["name"]["last"].upcase
          dup.firstname = user["user"]["name"]["first"].capitalize
          dup.email = user["user"]["email"]
          dup.password = "qualipso"
          dup.profile_type = if 7 % (j % 10 + 1) < 7
                               "user"
                             else
                               (j % 10 < 9 ? "designer" : "admin")
                             end
          if dup.save
            @results << { user: dup, status: 1 }
            puts "round ##{i + 1} : add #{dup.name.full} as #{dup.profile_type} (#{@count}/#{@number})"
            @created_count += 1
          else
            @results << { user: dup, status: 0 }
            puts "round ##{i + 1} : fail #{dup.name.full} as #{dup.profile_type} (#{@count}/#{@number})"
          end
        end
      end
      next unless @created_count.positive?

      require "rake"
      Qualipso::Application.load_tasks
      Rake::Task["es:import"].invoke
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  # Search for users
  # The parameters may contain :
  # *  query        The term to search for
  # *  deactivated  Whether includes the deactivated users into the records, default is false (pass "1" to enable it)
  # *  pending      Whether includes users with an invitation_token (default is '1')
  # *  only         A comma separated list of profiles to limit the records with
  # *  except       A comma separated list of profiles to exclude all the records with
  # *  order        (asc)ending or (desc)ending ordering option
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def search
    query = params[:query] || ""
    deactivated = params[:deactivated] == "1"
    pending = params[:pending] || "1"
    profiles = User.profile_types_in_db
    only = (params[:only] || "").split(",")
    except = (params[:except] || "").split(",")
    profiles = profiles.select { |profile| only.include?(profile) } if only.count.positive?
    profiles = profiles.reject { |profile| except.include?(profile) } if except.count.positive?
    @users = User.search(query, current_user).records
    @users = @users.order(:lastname)
    @users = if pending == "1"
               @users.where(deactivated: deactivated, profile_type: profiles)
             else
               @users.where(deactivated: deactivated, profile_type: profiles, invitation_token: nil)
             end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def update_groups
    groups = JSON.parse params[:groups]
    logger.debug groups.to_s
    @user = current_customer.users.find(params[:id])
    records = []
    groups.each do |group|
      group_rec = current_customer.groups.find_by_title(group["text"])
      records << group_rec
    end
    @user.update_attributes(groups: records)
    @user.save

    head :ok
  end

  def confirm_link_roles
    @user = current_customer.users.find params[:id]
    respond_to do |format|
      format.html {}
      format.js {}
      format.json do
        render_list "assignrole", :list_link_role_definition
      end
    end
  end

  # TODO: create RESTful routes.
  def link_roles
    @user = current_customer.users.find params[:id]
    selections = list_selection(:list_role_add_definition)

    selections&.each do |role|
      @user.roles << role
    end

    if @user.save
      flash[:success] = I18n.t("users.success.link_roles")
      redirect_to edit_user_path(@user)
    else
      fill_errors_hash(I18n.t("users.failure.link_roles"), @user)
      render :show
    end
  end

  # rubocop:disable Metrics/AbcSize
  def unlink_roles
    @roles = []
    @user = current_customer.users.find params[:id]
    roles_ids = JSON.parse params[:roles_ids]
    roles_ids.each do |role_id|
      role = current_customer.roles.find(role_id)
      if @user.roles.delete(role)
        @roles << role
        @succeed = true
      else
        @succeed = false
      end
    end
    if @succeed
      flash[:success] = I18n.t("users.success.unlink_roles")
    else
      flash.now[:error] = I18n.t("users.failure.unlink_roles")
      head :internal_server_error
    end
  end
  # rubocop:enable Metrics/AbcSize

  def list_linked_graphs
    @graphs   = []
    roles_ids = JSON.parse params[:roles_ids]

    @graphs = if current_user.process_power_user?
                current_customer.graphs.related_role_graphs_to_admin_or_designer(roles_ids)
              else
                current_customer.graphs.related_role_graphs(roles_ids)
              end

    respond_to do |format|
      format.json { render json: { graphs: @graphs.distinct.to_json(include: [:author]) } }
    end
  end

  def edit_avatar
    @user = current_customer.users.find params[:id]
    authorize @user, :update_avatar?
  end

  def update_avatar
    @user = current_customer.users.find(params[:id])
    authorize @user, :update_avatar?
    if @user.update_attributes(user_params)
      respond_to do |format|
        format.js { render :update_avatar }
        format.html do
          flash[:success] = I18n.t("controllers.users.successes.update_avatar")
          redirect_to edit_avatar_user_path(@user)
        end
      end
    else
      respond_to do |format|
        format.js { render :edit_avatar }
        format.html { redirect_to edit_avatar_user_path(@user) }
      end
    end
  end

  def serve_avatar
    @user = current_customer.users.find(params[:id])
    version = params[:version] || "thumb"

    path = "public"

    case version
    when "standard" then path += @user.avatar_url.to_s
    when "thumb" then path += @user.avatar_url(:thumb).to_s
    when "show" then path += @user.avatar_url(:show).to_s
    when "large" then path += @user.avatar_url(:large).to_s
    end

    send_file(CGI.unescape(path), disposition: "inline", x_sendfile: true)
  end

  def crop_avatar
    @user = current_customer.users.find(params[:id])
    authorize @user, :update_avatar?
  end

  def update_crop_avatar
    @user = current_customer.users.find(params[:id])
    authorize @user, :update_avatar?
    @user.crop_avatar(params[:crop_x], params[:crop_y], params[:crop_w], params[:crop_h])
    redirect_to edit_user_path(@user)
  end

  def interactions
    @user = current_customer.users.find(params[:id])
    @roles = @user.roles.active
    @graphs = []

    role_ids = []
    @roles.each do |role|
      role_ids << role.id
    end
    @graphs = current_user.related_role_graphs(role_ids)
  end

  def edit_metadata
    @user = current_user

    authorize @user, :update_metadata?

    respond_to do |format|
      format.html { render layout: "login_sso_layout" }
    end
  end

  def update_metadata
    @user = current_user

    authorize @user, :update_metadata?

    if current_user.update(general_user_params)
      flash[:success] = I18n.t("users.success.update_sso_metadata")
      redirect_to root_path
    else
      render :edit_metadata, layout: "login_sso_layout"
    end
  end

  private

  def user_params
    params.require(:user).permit(:avatar, :original_avatar_filename)
  end

  def general_user_params
    params.require(:user).permit(:firstname, :lastname, :phone, :mobile_phone, :language, :gender, :function, :service)
  end

  def list_link_role_definition
    {
      items: lambda {
        current_customer.roles.active.where.not(id: @user.roles)
      },
      search: lambda { |roles, term|
        roles.where(id: Role.search_list(term, current_user).where.not(id: @user.roles).to_a)
      },
      orders: {
        title: ->(roles) { roles.order("title") },
        title_inv: ->(roles) { roles.order("title DESC") },
        type: ->(roles) { roles.order("type, title") }
      }
    }
  end

  def list_role_add_definition
    list_link_role_definition.merge(
      items: -> { current_customer.roles.where.not(id: @user.roles) }
    )
  end

  def generate_file_name(ext)
    "#{current_customer.nickname}_#{t('users.xls.filename')}_#{I18n.l(Time.current, format: :file_export)}.#{ext}"
  end
end
