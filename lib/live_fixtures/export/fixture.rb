module LiveFixtures::Export::Fixture
  module_function
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
