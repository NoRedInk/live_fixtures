# An object that facilitates the import of fixtures into a database.
class LiveFixtures::Import
  NO_LABEL = nil

  # Instantiate a new Import with the directory containing your fixtures, and
  # the order in which to import them. The order should ensure fixtures
  # containing references to another fixture are imported AFTER the referenced
  # fixture.
  # @raise [ArgumentError] raises an argument error if not every element in the insert_order has a corresponding yml file.
  # @param root_path [String] path to the directory containing the yml files to import.
  # @param insert_order [Array<String>] a list of yml files (without .yml extension) in the order they should be imported.
  # @param [Hash] options the import options
  # @option options [Boolean] :skip_missing_tables whether to raise an ArgumentError if there isn't a yml file for each table in insert_order.
  # @option options [Boolean] :skip_missing_references whether to raise an error if an ID for a labeled reference cannot be found.
  # @return [LiveFixtures::Import] an importer
  # @see LiveFixtures::Export::Reference
  def initialize(root_path, insert_order, **options)
    @options = {skip_missing_tables: false, skip_missing_references: true}.merge(options)
    @root_path = root_path
    @table_names = Dir.glob(File.join(@root_path, '{*,**}/*.yml')).map do |filepath|
      File.basename filepath, ".yml"
    end
    @table_names = insert_order.select {|table_name| @table_names.include? table_name}
    if @table_names.size < insert_order.size && @options[:skip_missing_tables] == false
      raise ArgumentError, "table(s) mentioned in `insert_order` which has no yml file to import: #{insert_order - @table_names}"
    end
    @label_to_id = {}
  end

  # Within a transaction, import all the fixtures into the database.
  # @param class_names [Hash{Symbol => String}] a mapping table name => Model class, for any that don't follow convention.
  #
  # The very similar method: ActiveRecord::FixtureSet.create_fixtures has the
  # unfortunate side effect of truncating each table!!
  #
  # Therefore, we have reproduced the relevant sections here, without DELETEs,
  # with calling {LiveFixtures::Import::Fixtures#each_table_row_with_label} instead of
  # `AR::Fixtures#table_rows`, and using those labels to populate `@label_to_id`.
  # @see https://github.com/rails/rails/blob/4-2-stable/activerecord/lib/active_record/fixtures.rb#L496
  def import_all(class_names = {})
    @table_names.each { |n|
      class_names[n.tr('/', '_').to_sym] ||= n.classify if n.include?('/')
    }

    connection = ActiveRecord::Base.connection

    files_to_read = @table_names

    unless files_to_read.empty?
      connection.transaction(requires_new: true) do
        files_to_read.each do |path|
          table_name = path.tr '/', '_'
          class_name = class_names[table_name.to_sym] || table_name.classify

          ff = Fixtures.new(connection,
                            table_name,
                            class_name,
                            ::File.join(@root_path, path),
                            @label_to_id,
                            skip_missing_references: @options[:skip_missing_references])

          conn = ff.model_connection || connection
          ProgressBarIterator.new(ff).each do |table_name, label, row|
            conn.insert_fixture(row, table_name)
            @label_to_id[label] = conn.last_inserted_id(table_name) unless label == NO_LABEL
          end
        end
      end
    end
  end

  class ProgressBarIterator
    def initialize(ff)
      @ff = ff
      @bar = LiveFixtures.get_progress_bar(
        total:ff.fixtures.size,
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
end
