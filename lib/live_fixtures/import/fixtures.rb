require 'active_record/fixtures'

class LiveFixtures::Import
  # A labeled reference was not found.
  # Maybe the referenced model was not exported, or the insert order attempted
  # to import the reference before the referenced model?
  LiveFixtures::MissingReferenceError = Class.new(KeyError)
  class Fixtures
    delegate :model_class, :table_name, :fixtures, to: :ar_fixtures
    # ActiveRecord::FixtureSet for delegation
    attr_reader :ar_fixtures

    # @param connection [ActiveRecord::ConnectionAdapters::AbstractAdapter] connection to the database into which to import the data.
    # @param table_name [String] name of the database table to populate with models
    # @param class_name [Constant] the model's class name
    # @param filepath [String] path to the yml file containing the fixtures
    # @param label_to_id [Hash{String => Int}] map from a reference's label to its new id.
    # @param :skip_missing_references [Boolean] whether to raise an error if an ID for a labeled reference cannot be found.
    def initialize(connection, table_name, class_name, filepath, label_to_id, skip_missing_references: true)
      @skip_missing_references = skip_missing_references
      @ar_fixtures = ActiveRecord::FixtureSet.new connection,
        table_name,
        class_name,
        filepath
      @label_to_id = label_to_id
    end

    # Rewritten to take advantage of @label_to_id instead of AR::FixtureSet#identify,
    # and to make an iterator.
    #
    # @yieldparam table_name [String] the database table's name
    # @yieldparam label [String] the label for the model being currently imported
    # @yieldparam row [Hash{String => Value}] the model's attributes to be imported
    # Iterator which yields [table_name, label, row] for each fixture
    # (and for any implicit join table records). The block is expected to insert
    # the row and update @label_to_id with the record's newly assigned id.
    # @see https://github.com/rails/rails/blob/4-2-stable/activerecord/lib/active_record/fixtures.rb#L611
    def each_table_row_with_label
      join_table_rows = Hash.new { |h,table| h[table] = [] }

      fixtures.map do |label, fixture|
        row = fixture.to_hash

        reflection_class = reflection_class_for row

        reflection_class.reflect_on_all_associations.each do |association|
          next unless row[association.name.to_s]

          case association.macro
            when :belongs_to
              maybe_convert_association_to_foreign_key row, association

            when :has_and_belongs_to_many
              join_table_name = association.join_table

              targets = row.delete(association.name.to_s)
              targets = targets.split(/\s*,\s*/) unless targets.is_a?(Array)

              join_table_rows[join_table_name] << { targets: targets,
                                                    association: association,
                                                    label: label }
          end
        end

        yield [table_name, label, row]
      end

      join_table_rows.each do |table_name, rows|
        rows.each do |targets:, association:, label:|
          targets.each do |target|
            assoc_fk = @label_to_id[target] || target
            row = { association.foreign_key             => @label_to_id[label],
                    association.association_foreign_key => assoc_fk }
            yield [table_name, NO_LABEL, row]
          end
        end
      end
    end

    def model_connection
      model_class.connection if model_class.respond_to? :connection
    end

    private

    # Uses the underlying map of labels to return the referenced model's newly
    # assigned ID.
    # @raise [LiveFixtures::MissingReferenceError] if the label isn't found.
    # @param label_to_fetch [String] the label of the referenced model.
    # @return [Integer] the newly assigned ID of the referenced model.
    def fetch_id_for_label(label_to_fetch)
      @label_to_id.fetch(label_to_fetch)
    rescue KeyError
      return if @skip_missing_references

      raise LiveFixtures::MissingReferenceError, <<-ERROR.squish
      Unable to find ID for model referenced by label #{label_to_fetch} while
      importing #{model_class} from #{table_name}.yml. Perhaps it isn't included
      in these fixtures or it is too late in the insert_order and has not yet
      been imported.
      ERROR
    end

    def inheritance_column_name
      @inheritance_column_name ||= model_class && model_class.inheritance_column
    end

    # If STI is used, find the correct subclass for association reflection
    def reflection_class_for(row)
      return model_class unless row.include?(inheritance_column_name)

      row[inheritance_column_name].constantize
    rescue
      model_class
    end

    def maybe_convert_association_to_foreign_key(row, association)
      fk_name = (association.options[:foreign_key] || "#{association.name}_id").to_s

      # Do not replace association name with association foreign key if they are named the same
      return if association.name.to_s == fk_name

      value = row.delete(association.name.to_s)

      # support polymorphic belongs_to as "label (Type)"
      if association.options[:polymorphic] && value.sub!(/\s*\(([^\)]*)\)\s*$/, "")
        row[association.foreign_type] = $1
      end

      row[fk_name] = fetch_id_for_label(value)
    end

    private :ar_fixtures
  end
end
