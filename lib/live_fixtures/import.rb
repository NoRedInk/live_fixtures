# ActiveRecord::Fixtures are a powerful way of populating data in a db;
# however, its strategy for handling primary keys and associations is
# UNACCEPTABLE for use with a production db. LiveFixtures works around this.
#
#
########### Here's how ActiveRecord::Fixtures work ###########################
#
# Each record is assigned a label in its yml file. Primary key values are
# assigned using a guid algorithm that maps a label to a consistent integer
# between 1 and 2^30-1. Primary keys can then be assigned before saving any
# records to the db.
#
# Why would they do this? Because, this enables us to use labels in the
# Fixture yml files to refer to associations. For example:
#
#       <users.yml>
#       bob:
#         username: thebob
#
#       <posts.yml>
#       hello:
#         message: Hello everyone!
#         user: bob
#
# The ActiveRecord::Fixture system first converts every instance of `bob` and
# `hello` into an integer using ActiveRecord::Fixture#identify, and then can
# save the records IN ANY ORDER and know that all foreign keys will be valid.
#
# There is a big problem with this. In a test db, each table is empty and so the
# odds of inserting a few dozen records causing a primary key collision is
# very small. However, for a production table with a hundred million rows, this
# is no longer the case! Collisions abound and db insertion fails.
#
# Also, autoincrement primary keys will continue from the LARGEST existing
# primary key value. If we insert a record at 1,000,000,000 - we've reduced the
# total number of records we can store in that table in half. Fine for a test db
# but not ideal for production.
#
#
########### LiveFixtures work differently ####################################
#
# Since we want to be able to take advantage of normal autoincrement behavior,
# we cannot know the primary keys of each record before saving it to the db.
# Instead, we save each record, and then maintain a mapping (`@label_to_id`)
# from that record's label (`bob`), to its primary key (`213`). Later, when
# another record (`hello`) references `bob`, we can use this mapping to look up
# the primary key for `bob` before saving `hello`.
#
# This means that the order we insert records into the db matters: `bob` must
# be inserted before `hello`! This order is defined in INSERT_ORDER, and
# reflected in the order of the `@table_names` array.

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

  # https://github.com/rails/rails/blob/3-2-stable/activerecord/lib/active_record/fixtures.rb#L462
  # The very similar method: ActiveRecord::Fixtures.create_fixtures has the
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
