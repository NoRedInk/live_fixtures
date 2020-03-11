require 'benchmark'

# An object that facilitates the import of fixtures into a database.
class LiveFixtures::Import
  NO_LABEL = nil

  # Returns the insert order that was specified in the constructor or
  # the inferred one if none was specified.
  attr_reader :insert_order

  # Instantiate a new Import with the directory containing your fixtures, and
  # the order in which to import them. The order should ensure fixtures
  # containing references to another fixture are imported AFTER the referenced
  # fixture.
  # @raise [ArgumentError] raises an argument error if not every element in the insert_order has a corresponding yml file.
  # @param root_path [String] path to the directory containing the yml files to import.
  # @param insert_order [Array<String> | Nil] a list of yml files (without .yml extension) in the order they should be imported, or `nil` if these order is to be inferred by this class.
  # @param class_names [Hash{Symbol => String}] a mapping table name => Model class, for any that don't follow convention.
  # @param [Hash] opts export configuration options
  # @option opts [Boolean] show_progress whether or not to show the progress bar
  # @option opts [Boolean] skip_missing_tables when false, an error will be raised if a yaml file isn't found for each table in insert_order
  # @option opts [Boolean] skip_missing_refs when false, an error will be raised if an ID isn't found for a label.
  # @return [LiveFixtures::Import] an importer
  # @see LiveFixtures::Export::Reference
  def initialize(root_path, insert_order = nil, class_names = {}, **opts)
    defaut_options = { show_progress: true, skip_missing_tables: false, skip_missing_refs: false }
    @options = defaut_options.merge(opts)
    @root_path = root_path
    @table_names = Dir.glob(File.join(@root_path, '{*,**}/*.yml')).map do |filepath|
      File.basename filepath, ".yml"
    end

    @class_names = class_names
    @table_names.each { |n|
      @class_names[n.tr('/', '_').to_sym] ||= n.classify if n.include?('/')
    }

    @insert_order = insert_order
    @insert_order ||= InsertionOrderComputer.compute(@table_names, @class_names, compute_polymorphic_associations)

    @table_names = @insert_order.select {|table_name| @table_names.include? table_name}
    if @table_names.size < @insert_order.size && !@options[:skip_missing_tables]
      raise ArgumentError, "table(s) mentioned in `insert_order` which has no yml file to import: #{@insert_order - @table_names}"
    end

    @label_to_id = {}
    @alternate_imports = {}
  end

  # Within a transaction, import all the fixtures into the database.
  #
  # The very similar method: ActiveRecord::FixtureSet.create_fixtures has the
  # unfortunate side effect of truncating each table!!
  #
  # Therefore, we have reproduced the relevant sections here, without DELETEs,
  # with calling {LiveFixtures::Import::Fixtures#each_table_row_with_label} instead of
  # `AR::Fixtures#table_rows`, and using those labels to populate `@label_to_id`.
  # @see https://github.com/rails/rails/blob/4-2-stable/activerecord/lib/active_record/fixtures.rb#L496
  def import_all
    connection = ActiveRecord::Base.connection
    show_progress = @options[:show_progress]

    # TODO: should be additive with alternate_imports so we can delete the fixture file
    files_to_read = @table_names

    unless files_to_read.empty?
      connection.transaction(requires_new: true) do
        files_to_read.each do |path|
          table_name = path.tr '/', '_'
          class_name = @class_names[table_name.to_sym] || table_name.classify

          ff = Fixtures.new(connection,
                            table_name,
                            class_name,
                            ::File.join(@root_path, path),
                            @label_to_id,
                            skip_missing_refs: @options[:skip_missing_refs])

          conn = ff.model_connection || connection
          if alternate = @alternate_imports[table_name]
            time = Benchmark.ms do
              alternate.call(@label_to_id)
            end
            puts "Imported %s in %.0fms" % [table_name, time] if show_progress
          else
            iterator = show_progress ? ProgressBarIterator : SimpleIterator
            iterator.new(ff).each do |tname, label, row|
              conn.insert_fixture(row, tname)
              @label_to_id[label] = conn.send(:last_inserted_id, tname) unless label == NO_LABEL
            end
          end
        end
      end
    end
  end

  def override(table, proc)
    @alternate_imports[table] = proc
    self
  end

  private

  # Here we go through each of the fixture YAML files to see what polymorphic
  # dependencies exist for each of the models.
  # We do this by inspecting the value of any field that ends with `_type`,
  # for example `author_type`, `assignment_type`, etc.
  # Becuase we can't know all the possible types of a polymorphic association
  # we compute them from the YAML file contents.
  # Returns a Hash[Class => Set[Class]]
  def compute_polymorphic_associations
    polymorphic_associations = Hash.new { |h, k| h[k] = Set.new }

    connection = ActiveRecord::Base.connection
    files_to_read = @table_names

    files_to_read.each do |path|
      table_name = path.tr '/', '_'
      class_name = @class_names[table_name.to_sym] || table_name.classify

      # Here we use the yaml file and YAML.load instead of ActiveRecord::FixtureSet.new
      # because it's faster and we can also check whether we actually need to
      # load the file: only if it includes "_type" in it, otherwise there will be
      # no polymorphic types in there.

      filename = ::File.join(@root_path, "#{path}.yml")
      file = File.read(filename)
      next unless file =~ /_type/

      yaml = YAML.load(file)
      yaml.each do |key, object|
        object.each do |field, value|
          next unless  field.ends_with?("_type")

          begin
            polymorphic_associations[class_name.constantize] << value.constantize
          rescue NameError
            # It might be the case that the `..._type` field doesn't actually
            # refer to a type name, so we just ignore it.
          end
        end
      end
    end

    polymorphic_associations
  end

  class ProgressBarIterator
    def initialize(ff)
      @ff = ff
      @bar = LiveFixtures.get_progress_bar(
        total:ff.fixtures.size,
        # ff.model_class is nil for Module::ClassName models sometimes
        title: ff.model_class.name
      )
    end

    def each
      @ff.each_table_row_with_label do |*args|
        yield(*args)
        @bar.increment unless @bar.finished?
      end
      @bar.finish
    end
  end

  class SimpleIterator
    def initialize(ff)
      @ff = ff
    end

    def each
      puts @ff.model_class.name
      @ff.each_table_row_with_label do |*args|
        yield(*args)
      end
    end
  end
end
