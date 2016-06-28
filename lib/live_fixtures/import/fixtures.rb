require 'active_record/fixtures'

#rubocop:disable Style/PerlBackrefs

class LiveFixtures::Import
  class Fixtures
    delegate :model_class, :table_name, :fixtures, to: :ar_fixtures
    attr_reader :ar_fixtures

    def initialize(connection, table_name, class_name, filepath, label_to_id)
      @ar_fixtures = ActiveRecord::Fixtures.new connection,
                                                table_name,
                                                class_name,
                                                filepath
      @label_to_id = label_to_id
    end

    # https://github.com/rails/rails/blob/3-2-stable/activerecord/lib/active_record/fixtures.rb#L569
    # Rewritten to take advantage of @label_to_id instead of AR::Fixtures#identify,
    # and to make an iterator.
    #
    # Iterator which yields [table_name, label, row] for each fixture
    # (and for any implicit join table records)
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
              join_table_name = association.options[:join_table]

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

      row[fk_name] = @label_to_id[value]
    end

    private :ar_fixtures
  end
end