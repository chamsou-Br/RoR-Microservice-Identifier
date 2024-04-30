# frozen_string_literal: true

class FieldValueCodec
  class << self
    #
    # Encodes an array of {FieldValue} records into a hash that can be
    # serialized into JSON.  Keys are IDs {FormField} records and values are
    # arrays serialized {FieldValue} records whose `form_field_id` matches the
    # key of the hash entry.  Scalar values are stored as plain text strings and
    # entities are encoded as simple `type`/`id` structs so they can be reified
    # later once deserialized.
    #
    # @param field_values [Array<FieldValue>] field_values
    # @param empty value to be used when encoded values are empty
    # @return [Hash{String => Array<PaperTrail::RecordReference, String>}, nil]
    # @example Encoding a field with 2 non-scalar values
    #   values = [
    #     FieldValue.create(entity_id: 42,
    #                       entity_type: "Bling",
    #                       form_field_id: 1),
    #     FieldValue.create(entity_id: 43,
    #                       entity_type: "Bling",
    #                       form_field_id: 1)
    #   ]
    #
    #   FieldValueCodec.encode_values(values)
    #   => {
    #     "1" => [
    #       #<PaperTrail::RecordReference @id="42" @type="Bling">,
    #       #<PaperTrail::RecordReference @id="43" @type="Bling">
    #     ]
    #   }
    def encode_values(field_values, empty: nil)
      json = field_values.each_with_object({}) do |field_value, hsh|
        json_key = field_value.form_field_id.to_s
        json_value = encode_value(field_value)

        if hsh.key?(json_key)
          hsh[json_key] << json_value
        else
          hsh[json_key] = [json_value]
        end
      end

      json.empty? ? empty : json
    end

    #
    # Restores a JSON hash into a new hash whose keys for {FormField} records
    # and whose values are array of strings or reified {ActiveRecord::Base}
    # records.
    #
    # @param hsh [Hash{String => Array<String, Hash{String => String}>}]
    # @return [Hash{FormField => Array<String, ActiveRecord::Base>}]
    # @todo Better document and test this method when implementing the timeline
    #   API
    def decode_hash(hsh)
      hsh.transform_values { |values| values.map { |v| decode_json_value(v) } }
         .transform_keys { |form_field_id| FormField.find(form_field_id) }
    end

    private

    #
    # @param field_value [FieldValue]
    # @return [Hash, String]
    #
    def encode_value(field_value)
      if field_value.entity_id.blank? && field_value.entity_type.blank?
        field_value.value
      else
        PaperTrail::RecordReference.new(field_value.entity_type,
                                        field_value.entity_id)
      end
    end

    #
    # @param value [String, Hash{String => String}]
    # @return [String, ActiveRecord::Base]
    #
    def decode_json_value(value)
      if value.is_a?(Hash)
        PaperTrail::RecordReference.from_h(value).reify
      else
        value
      end
    end
  end
end
