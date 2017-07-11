class LiveFixtures::Import
  NO_LABEL = nil

  def initialize(root_path, insert_order)
    @root_path = root_path
    @table_names = Dir.glob(File.join(@root_path, '{*,**}/*.yml')).map do |filepath|
      File.basename filepath, ".yml"
    end
    @table_names = insert_order.select {|table_name| @table_names.include? table_name}
    if @table_names.size < insert_order.size
      raise ArgumentError, "table(s) mentioned in `insert_order` which has no yml file to import: #{insert_order - @table_names}"
    end
    @label_to_id = {}
  end

  # https://github.com/rails/rails/blob/4-2-stable/activerecord/lib/active_record/fixtures.rb#L496
  # The very similar method: ActiveRecord::FixtureSet.create_fixtures has the
  # unfortunate side effect of truncating each table!!
  #
  # Therefore, we have reproduced the relevant sections here, without DELETEs,
  # with calling `LF::Import::Fixtures#each_table_row_with_label` instead of
  # `AR::Fixtures#table_rows`, and using those labels to populate `@label_to_id`.
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
                            @label_to_id)

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
