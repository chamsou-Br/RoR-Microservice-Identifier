# frozen_string_literal: true

# The class is responsible for creating predefined form fields and the relevant
# field items related to the `User` model for a given customer.

class UserFormFields
  USER_PERSONAL_INFO = { app_model: :user, form_section: :user_personal_info,
                         custom: false }.freeze
  USER_EXTRA_INFO = { app_model: :user, form_section: :user_extra_info,
                      custom: false }.freeze

  DEFAULT_USER_PERSONAL_FIELDS = [
    { field_name: :lastname, sequence: 0, field_type: :model_attribute,
      value_editable_by: :user_admin, required_state: :required_by_model },
    { field_name: :firstname, sequence: 1, field_type: :model_attribute,
      value_editable_by: :user_admin, required_state: :required_by_model },
    { field_name: :email, sequence: 2, field_type: :model_attribute,
      editable: false, value_editable_by: :noone,
      required_state: :preset_value },
    { field_name: :phone, sequence: 3, field_type: :model_attribute,
      value_editable_by: :user_admin_or_user }, # should be office_phone
    { field_name: :mobile_phone, sequence: 4, field_type: :model_attribute,
      value_editable_by: :user_admin_or_user },

    # The following three fields have field items
    { field_name: :language, sequence: 5, field_type: :model_attribute,
      value_editable_by: :user_admin_or_user },
    { field_name: :gender, sequence: 6, field_type: :model_attribute,
      value_editable_by: :user_admin_or_user },
    { field_name: :mail_frequency, sequence: 7, field_type: :model_attribute,
      value_editable_by: :user_admin_or_user }
  ].freeze

  DEFAULT_USER_EXTRA_FIELDS = [
    { field_name: :function, sequence: 0, field_type: :model_attribute,
      value_editable_by: :user_admin },
    { field_name: :service, sequence: 1, field_type: :model_attribute,
      value_editable_by: :user_admin }, # should be department
    { field_name: :supervisor, sequence: 2, field_type: :model_attribute,
      value_editable_by: :user_admin },
    { field_name: :working_date, sequence: 3, field_type: :model_attribute,
      value_editable_by: :user_admin }, # should be start_date
    { field_name: :user_module_profile, sequence: 4,
      field_type: :actor_attribute, value_editable_by: :user_admin },
    { field_name: :process_profile, sequence: 5, field_type: :actor_attribute,
      value_editable_by: :user_admin },
    { field_name: :improver_profile, sequence: 6, field_type: :actor_attribute,
      value_editable_by: :user_admin },
    { field_name: :risk_profile, sequence: 7, field_type: :actor_attribute,
      value_editable_by: :user_admin },
    { field_name: :time_zone, sequence: 8, field_type: :model_attribute,
      value_editable_by: :current_user },
    { field_name: :user_attachments, sequence: 9, field_type: :model_attribute,
      value_editable_by: :user_admin }
  ].freeze

  def self.create_form_fields(customer)
    # Bailing out if there are ANY user form fields for the customer.
    return nil if customer.form_fields.user_predef.any?

    create_user_fields(customer)
  end

  def self.create_user_fields(customer)
    [
      { fields: DEFAULT_USER_PERSONAL_FIELDS, opts: USER_PERSONAL_INFO },
      { fields: DEFAULT_USER_EXTRA_FIELDS, opts: USER_EXTRA_INFO }
    ].each do |params|
      params[:fields].each do |f|
        customer.form_fields.create!(f.merge(params[:opts]))
      rescue ActiveRecord::RecordNotUnique
        puts "Record for #{f} already exists"
      end
    end

    user_field_items(customer)
  end

  def self.user_field_items(customer)
    predef_fields = customer.form_fields.user_predef

    create_items(predef_fields, "language",
                 Qualipso::Application::AVAILABLE_LOCALES.map(&:to_s))
    create_items(predef_fields, "gender", User::GENDER)
    create_items(predef_fields, "mail_frequency", User::MAIL_FREQUENCY)
  end

  def self.create_items(predef_fields, field_name, array)
    field = predef_fields.find_by(field_name: field_name)

    array.each_with_index do |value, index|
      field.field_items << FieldItem.new(
        activated: true,
        i18n_key: value,
        sequence: index
      )
    end
  end

  ##
  # Return all predefined fields grouped by their model type
  # Not sure where this is needed...
  #
  def self.predefined_form_fields
    {
      User.to_s => [DEFAULT_USER_PERSONAL_FIELDS,
                    DEFAULT_USER_EXTRA_FIELDS].flatten
    }
  end

  # This method creates a hash to keep in memory the name of field and the
  # corresponding field items. The keys are the :field_name of the :form_field,
  # and the value is a hash, where the keys are the actual field_item value or
  # i18n_key and its value the reference of the actual field item:
  #   { :language => { :en => item,
  #                    :es => item } }
  #
  # @param [Hash] field_items_mapping Hash where the mapping is stored
  # @param [ActiveRecord::Relation] the pre-defined FormField's from the User
  # model of the customer.
  #
  def self.map_field_items(field_items_mapping, predef_fields)
    %w[gender language mail_frequency].each do |field_name|
      field = predef_fields.find_by(field_name: field_name)
      field_items_mapping[field_name] = {}
      field.field_items.each do |item|
        field_items_mapping[field_name][item.i18n_key] = item
      end
    end
  end
end
