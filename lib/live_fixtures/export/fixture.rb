# Exposes functionality to serialize an ActiveRecord record (a model) into a
# YAML fixture.
module LiveFixtures::Export::Fixture
  module_function
  # YAML-Serializes the provided model, including any references and additional
  # attribtues.
  # @param model [ActiveRecord::Base] an ActiveRecord record to serialize
  # @param references [Symbol, Array<Symbol>] the names of associations whose foreign_keys should be replaced with references
  # @param more_attributes [Hash{String => Time, DateTime, Date, Hash, String, LiveFixtures::Export::Template, LiveFixtures::Export::Reference, #to_s}] a hash of additional attributes to serialize with each record.
  # @return [String] the model serialized in YAML, with specified foreign_keys replaced by references, including additional attributes.
  def to_yaml(model, references = [], more_attributes = {})
    table_name = model.class.table_name

    more_attributes.merge! attributes_from_references(model, references)

    <<-YML
#{table_name}_#{model.id || SecureRandom.uuid.underscore}:
  #{yml_attributes(model, more_attributes)}

    YML
  end

  private_class_method def attributes_from_references(model, references)
    {}.tap do |options|
      Array(references).each do |assoc_name|

        if model.respond_to? assoc_name # need to check #respond_to? because some assoc only exist in certain subclasses
          assoc_model = model.send assoc_name
        end

        if assoc_model.present?
          options["#{assoc_name}_id"] = LiveFixtures::Export::Reference.new(assoc_name, assoc_model)
        end
      end
    end
  end

  private_class_method def yml_attributes(model, more_attributes)
    model.attributes.merge(more_attributes).map do |name, value|
      next if %w{id}.include? name
      next if value.nil?

      if model.class.type_for_attribute(name).is_a? ActiveRecord::Type::Serialized
        value = model.class.type_for_attribute(name).type_cast_for_database value
      end

      yml_value ||= case value
                      when Time, DateTime
                        value.utc.to_s(:db)
                      when Date
                        value.to_s(:db)
                      when Hash
                        value.to_yaml.inspect
                      when String
                        value.inspect
                      when LiveFixtures::Export::Template
                        value.code
                      when LiveFixtures::Export::Reference
                        name, value = value.name, value.value
                        "#{value.class.table_name}_#{value.id}"
                      else
                        value.to_s
                    end

      "#{name}: " + yml_value
    end.compact.join("\n  ")
  end
end
