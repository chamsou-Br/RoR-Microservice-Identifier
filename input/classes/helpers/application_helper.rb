# rubocop:disable all
module ApplicationHelper

  def react_component(component_name='Application', props={})
    props_json = escape_javascript props.to_json
    render inline: "
    <% content_for :specific_head_resources do %>
      <%= stylesheet_packs_with_chunks_tag '#{component_name}' %>
    <% end %>
    <div id='#{component_name}'></div>
    <%= javascript_packs_with_chunks_tag '#{component_name}' %>
    <script>
        window.BootFromEnvironment('#{component_name}',JSON.parse('#{props_json}'))
    </script>
    "
  end

  ES_SIZE_ALL = 100000

  RE_ISO8601 = /\A([\+-]?\d{4}(?!\d{2}\b))((-?)((0[1-9]|1[0-2])(\3([12]\d|0[1-9]|3[01]))?|W([0-4]\d|5[0-2])(-?[1-7])?|(00[1-9]|0[1-9]\d|[12]\d{2}|3([0-5]\d|6[1-6])))([T\s]((([01]\d|2[0-3])((:?)[0-5]\d)?|24\:?00)([\.,]\d+(?!:))?)?(\17[0-5]\d([\.,]\d+)?)?([zZ]|([\+-])([01]\d|2[0-3]):?([0-5]\d)?)?)?)?\z/

  def ico_error(params)
    object = params[:object]
    field = params[:field]
    title = params[:title]
    res = "<span class=\"ico-errors\">"
    if object.errors[field].any?
      res += image_tag("errors-form/p-error.png", :size => "25x25", :alt => "", :title => "")
      res += "<span class=\"box-errors\">"
      res += image_tag("errors-form/arrow-box.png", :size => "12x28", :alt => "", :class => "arrow-box")
      res += "<span class=\"content-message\">"
      res += "<span class=\"title-error\">#{title}</span>"

      object.errors[field].each do |error|
        res += "<span>#{error}</span>"
      end

      res += "</span>"
      res += "</span>"
    end
    res += "</span>"
    return res.html_safe
  end

  def flash_message(flash)
    return "" unless flash.any?

    res = ""
    flash.each do |message_type, messages|
      res += "<div style='height:auto;' class='notifie_specific_spacer tiny'>"
      res += "<div class='notification_bar "
      # Todo: Use ternary conditions.
      # Todo: Think about converting at the controller level, the 'notice' symbol to 'success'.
      res += ( ( message_type == "success" || message_type == "notice" ) ? "prevent" : ( message_type == "error" ? "warning" : "alert" ) )
      res += "_bar' >"
      res += "<div class='inner_bar'>"
      res += "<span class='specific_text'>"

      res += if messages.respond_to?(:map)
               messages.map { |message| "<p>#{message}</p>" }.join
             else
               messages.to_s
             end
      res += "</span>"
      res += "<div class='close_bar'><i class='fa fa-times'></i></div>"
      res += "</div>"
      res += "</div>"
      res += "</div>"
    end

    res.html_safe
  end

  def modal_errors(errors)
    res = ""
    errors.each do |error_type, error_messages|
      logger.debug error_messages
      res += filter_errors(error_messages)
    end
    return res.html_safe
  end

  def devise_custom_errors
    return "" if resource.errors.empty?

    messages = resource.errors.full_messages.map { |msg| "#{msg}<br/>" }.join

    html = <<-HTML
    <p class="error">
      #{messages}
    </p>
    HTML

    html.html_safe
  end

  def fill_errors_hash(basic_msg, model)
    @errors = { :warning => [basic_msg] }
    if !model.nil?
      logger.debug "#{basic_msg} : #{model.errors.messages}"
      model.errors.messages.each do |key, msg|
        msg.each do |one_msg|
          @errors[:warning] << one_msg
        end
      end
    end
  end

  def wf_entity_state_to_partial(wf_entity)
    if wf_entity.in_edition?
      'new'
    elsif wf_entity.in_verification?
      'verify'
    elsif wf_entity.in_approval?
      'approve'
    elsif wf_entity.in_publication? or wf_entity.in_scheduled_publication?
      'publish'
    elsif wf_entity.in_application?
      'apply'
    else
      'activate'
    end
  end

  def format_for_bip(error_message)
    [" #{error_message}"]
  end

  #
  # Parses a given ISO-8601-compliant time string into a {Time} or `nil` if the
  # given `str_time` is not ISO-8601 compliant.
  #
  # @param [String] str_time
  #
  # @return [Time, nil]
  # @see RE_ISO8601
  #
  def parse_iso8601(str_time)
    if str_time =~ ApplicationHelper::RE_ISO8601
      Time.parse(str_time)
    else
      nil
    end
  end

  def available_locales_extended(options = {})
    extented = Struct.new(:locale, :name)
    current = I18n.locale
    locales = I18n.available_locales.map do |locale|
      I18n.locale = locale
      options[:array] ? [locale, I18n.t('name')] : extented.new(locale, I18n.t('name'))
    end
    I18n.locale = current
    locales
  end

  # options.policy conditionally output the button given the corresponding association :rename? policy
  # options.only restrict the activation of the link to this model only
  def link_to_rename(association, id, options = {})
    association = association.to_s
    if options[:policy]
      return '' unless policy(association.classify.constantize).rename?
    end
    data = {
      :modal  => 'modal',
      :effect => 'effect-1',
      :many   => false,
      :param  => true,
    }
    data[:class] = options[:only] if options[:only]
    link_to send("rename_modal_#{association}_path"),
            :id     => id,
            :class  => 'md-trigger',
            :remote => true,
            :data   => data,
            :title => t('common.rename') do
      # White spaces are required to avoid a graphic clip issue
      (
        ' ' +
        image_tag('referential/rename-rep.svg', :size => '32x32') +
        ' ' +
        content_tag(:span) { t('common.rename') } +
        ' '
      ).html_safe
    end
  end

  def liiist_for(models, behaviors, options)
    classes = ['list']
    classes << (options[:class] || 'list-default')
    content_tag(:div, class: classes) do
      content_tag(:div, class: ['list-head'].concat(behaviors)) do
        content = ''
        behaviors.each do |b|
          case b
            when :selectable
              content += content_tag(:input, type: 'checkbox', class: 'list-select') {}
            when :expandable
              content += image_tag('referential/expand-icon.svg', title: I18n.t('common.expand'), class: %w{list-expand toggle})
            when :sortable
              content += content_tag(:select, class: %w{list-sort toggle}) do
                opts = ''
                options[:sorts].each do |sort|
                  data = sort[:reverse] ? { reverse: '' } : {}
                  opts += content_tag(:option, value: sort[:target], data: data, selected: sort[:selected]) { sort[:label] }
                end
                opts.html_safe
              end
            when :filterable
              content += content_tag(:ul, class: 'list-filter') do
                lis = ''
                options[:filters].each do |filter|
                  lis += content_tag(:li) do
                    link_to("?filter=#{filter[:id]}", class: filter[:active] ? ['active'] : '') { filter[:label] }
                  end
                end
                lis.html_safe
              end
            when :searchable
              content += content_tag(:input, type: 'text', class: %w{list-search live-update}, placeholder: I18n.t('common.search'), data: { text: options[:liveupdate_text] || '.title a' }) {}
            else
          end
        end
        content.html_safe
      end + content_tag(:ul, class: 'list-body', data: { model: models[0].class.to_s  }) do
        render models
      end
    end
  end

  def list_for(models, behaviors, options)
    behaviors_s = behaviors.map { |b| b.to_s }
    classes = ['list']
    classes.push('list-default') unless options[:class]
    if options[:class]
      classes.push(options[:class]) if options[:class].is_a? String
      classes.concat(options[:class]) if options[:class].is_a? Array
    end
    content_tag(:div, class: classes) do
      head = content_tag(:div, class: ['list-head'].concat(behaviors_s)) do
        content = ''
        behaviors.each do |b|
          case b
            when :selectable
              content += content_tag(:input, type: 'checkbox', class: 'list-select') {}
            when :expandable
              content += image_tag('referential/expand-icon.svg', title: I18n.t('common.expand'), class: %w{list-expand toggle})
            when :sortable
              content += content_tag(:select, class: %w{list-sort toggle}) do
                opts = ''
                options[:sorts].each do |sort|
                  data = sort[:reverse] ? { reverse: '' } : {}
                  opts += content_tag(:option, value: sort[:target], data: data) { sort[:label] }
                end
                opts.html_safe
              end
            when :filterable
              content += content_tag(:ul, class: 'list-filter') do
                lis = ''
                options[:filters].each do |filter|
                  classes = []
                  classes.push('active') if filter[:active]
                  filter[:computed] = models.select(&filter[:select])
                  lis += content_tag(:li) do
                    link_to("##{filter[:id]}", class: classes) do
                      (filter[:label] + content_tag(:span, class: "count_lbl") { " #{filter[:computed].count}" }).html_safe
                    end
                  end
                end
                lis.html_safe
              end
            when :searchable
              content += content_tag(:input, type: 'text', class: %w{list-search live-update}, placeholder: I18n.t('common.search'), data: { text: options[:liveupdate_text] || '.title a' }) {}
            else
          end
        end
        content.html_safe
      end
      body = content_tag(:ul, class: 'list-body') do
        content = ''
        models.each_with_index do |model, index|
          classes = ['list-item']
          classes.push(index % 2 ? 'even' : 'odd')
          filters = []
          if behaviors.include?(:filterable) and options[:filters]
            options[:filters].each do |filter|
              filters.push(filter[:id]) if filter[:computed].include?(model)
            end
          end
          content += content_tag(:li, class: classes, data: { id: model.id, filter: filters.join(' ') }) {
            yield(model)
          }.html_safe
        end
        content.html_safe
      end
      head + body
    end.html_safe
  end

  def list_item(model)
    content_tag(:li, class: 'list-item') do
      yield.html_safe
    end
  end

  def list_box_tag
    content_tag(:div, class: %w{span05 adjust}) do
      content_tag(:input, type: 'checkbox', class: 'list-select') {}
    end
  end

  def list_favor_tag(model)
    content_tag(:div, class: %w{span05 adjust big}) do
      directory_favor_links(model)
    end
  end

  def list_expand_tags_tag(model)
    if model.tags.any?
      content_tag(:p, class: %W{list-expand labels}) do
        tags_for(model)
      end
    else
      ''
    end
  end

  def tags_for(model, options = {})
    iterate = options[:iterate] || model.tags
    field = options[:field] || :label
    if iterate.any?
      content = content_tag(:span, class: 'label') { content_tag(:span) { content_tag(:i, class: 'fa fa-tags') {} } }
      iterate.each do |item|
        content += content_tag(:span, class: 'label') { link_to(item) { content_tag(:span) { item[field] } } }
      end
      content.html_safe
    else
      ''
    end
  end

  def list_property_button(model)
    path = send("show_properties_#{model.class.name.downcase}_path", model.id)
    content_tag(:div, class: %w{span1 adjust}) do
      content_tag(:button, :class => 'pushdetails', :title => I18n.t('common.property.other'), :onclick => "location.href='#{path}'") do
        I18n.t 'common.property.other'
      end
    end
  end

  def list_cell_tag(options = {})
    classes = []
    size = options[:size] || 1
    if options[:class]
      classes.push(options[:class]) if options[:class].is_a? String
      classes.concat(options[:class]) if options[:class].is_a? Array
    end
    classes.push('adjust') if options[:adjust]
    classes.push("span#{size}")
    content_tag(:div, class: classes) do
      yield.html_safe
    end
  end

  def list_expand_tag(options = {})
    tag = options[:tag] || :p
    classes = ['list-expand']
    if options[:class]
      classes.push(options[:class]) if options[:class].is_a? String
      classes.concat(options[:class]) if options[:class].is_a? Array
    end
    classes.push('sub') unless options[:nosub]
    content_tag(tag, class: classes) do
      yield.html_safe
    end
  end

  def path_for(directory)
    content_tag(:span, class: 'breadcrumbs') do
      directory.self_and_ancestors.map do |node|
        content_tag(:span, class: 'breadcrumbs-item') { link_to(node) { node.name } }
      end.join(content_tag(:span, class: 'breadcrumbs-separator') { '/' }).html_safe
    end
  end

  def is_dark_color(hex_color)
    # on enlève le # de début éventuellement
    if hex_color.length > 6
      hex_color = hex_color[1..6]
    end
    red_hex = hex_color[0..1]
    green_hex = hex_color[2..3]
    blue_hex = hex_color[4..5]
    # puts "red_hex: #{red_hex} ; green_hex: #{green_hex} ; blue_hex:#{blue_hex}"
    red_integer = red_hex.convert_base(16,10).to_i
    green_integer = green_hex.convert_base(16,10).to_i
    blue_integer = blue_hex.convert_base(16,10).to_i
    # puts "red_integer: #{red_integer} ; green_integer: #{green_integer} ; blue_integer:#{blue_integer}"
    sum_integers = red_integer + green_integer + blue_integer
    # puts "sum_integers : #{sum_integers}"
    # pure_white = 765 ; pure_black = 0
    seuil = 382.5
    return sum_integers < seuil
  end

  # Utilisé pour encapsulé les select_tag dans un field_with_error en cas d'erreur de validates
  def field_with_error(object, method, &block)
    if block_given?
      if  object.errors[method].empty?
        concat capture(&block).html_safe
      else
        concat ('<div class="fieldWithErrors">' + capture(&block) + '</div>').html_safe
      end
    end
  end

  # useful in combination with StrongParameters
  def isParamAsArrayOfInteger?(key)
    if params.include?(key)
      array = params[key].split(',').flatten
      not_expected = array.bsearch{|x| x !~ /\A\d+\z/}
      !not_expected # cant find one element which do not meet expectations
    else
      true
    end
  end

  def date_sql_format(date_to_format, day_end=false)
    splitted_date = date_to_format.to_s.split("/")
    if !splitted_date[2].nil? && !splitted_date[1].nil? && !splitted_date[0].nil?
      if day_end
        return "#{splitted_date[2]}-#{splitted_date[1]}-#{splitted_date[0]} 23:59:59"
      else
        return "#{splitted_date[2]}-#{splitted_date[1]}-#{splitted_date[0]}"
      end
    else
      return nil
    end
  end


  private
  def filter_errors(messages)
    res = ""
    if messages.instance_of? String
      res += messages.to_s
    else
      messages.each do |a_message|
        res += "<p>" + a_message + "</p>"
      end
    end
    res
  end

  def humanize_log(log)
    scope = 'helpers.graphs.humanize_log'
    wf_entity = get_wf_entity(log)
    my_state = log.action
    if my_state === "approved" and !wf_entity.verifiers.blank? and wf_entity.approvers.blank?
      return I18n.t("verified", :scope => scope)
    end
    I18n.t(my_state.to_s, :scope => scope)
  end

  #
  # Returns the current customer user matching the given `id` if any
  #
  # @param [Integer, String, nil] id
  #
  # @return [User, nil]
  # @note This depends on the class including this helper to expose a
  # `current_customer` that returns a {Customer}.
  #
  def retrieve_user(id)
    return if id.nil?

    # @type [User]
    user = current_customer.users.find(id)
    user.name.full
  end

  def display_log?(log)
    wf_entity = get_wf_entity(log)
    if log.action === "approved" and wf_entity.verifiers.blank? and wf_entity.approvers.blank?
      return false
    elsif log.action === "verified" and wf_entity.verifiers.blank?
      return false
    end
    true
  end

  def get_wf_entity(log)
    begin
      wf_entity = log.document
    rescue
      wf_entity = log.graph
    end
    wf_entity
  end

  def body_class(class_name = 'body-page')
    content_for(:body_class, class_name)
  end

  def error_messages_for(object, attribute)
    if object.errors[attribute].any?
      messages = object.errors[attribute].map { |msg| content_tag(:li, msg)}.join.html_safe
      content_tag(:div, content_tag(:ul, messages), class: 'field-error-messages')
    else
      ''
    end
  end

  # returns a polymorphic path prepended with :improver for the model of the improver.
  # It's quite a poor solution but I don't know something good to associate a model with
  # a namespace
  def modular_polymorphic_path(base, *args)
    polymorphic_path(modular_array_for_path(base, *args))
  end

  def modular_array_for_path(base, *args)
    if [Event, Act, Audit].include?(base.class)
      return [:improver, base, *args]
    else
      return [base, *args]
    end
  end

  def is_integer? string
    true if Integer(string) rescue false
  end

        # Used for best_in_place
        def render_for_html(attr)
          sanitize(attr)&.gsub(/\n/, '<br/>')&.html_safe
        end

end





ActionView::Base.send :include, BestInPlaceFormatter::ActionViewExtensions::Formatter

# rubocop:enable all
