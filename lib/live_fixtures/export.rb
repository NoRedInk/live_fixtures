# This module is meant to be `include`ed into your export class.
#
# 1. Call #set_export_dir to set the dir where files should be created.
#    If the dir does not already exist, it will be created for you.
#
# 2. Then call #export_fixtures for each db table, which will produce
#    one yml file for each db table. Do *not* call export_fixtures multiple
#    times for the same db table - that will overwrite the file each time!

module LiveFixtures::Export
  # Templates allow you to export fixtures containing erb, that will be evaluated at the time of fixture import.
  # You should initialize them with a String containing the erb to evaluate, like
  # @example A template with export and import times.
  #    Template.new("<%= \"I was exported at #{Time.now} and imported at \" + Time.now.to_s %>")
  Template  = Struct.new(:code)

  # References represent associations between fixtures, in the same way that foreign_keys do for records.
  # These will be initialized for you based on the contents of `with_references` passed to `export_fixtures`.
  # They will be initialized with the name of the association (a Symbol) and the particular associated model.
  Reference = Struct.new(:name, :value)

  private

  # Specify the directory into which to export the yml files containing your fixtures.
  # The directory will be created if it does not yet exist.
  # @param dir [String] a path to a directory into which the fixtures will be exported.
  def set_export_dir(dir)
    @dir = dir
    FileUtils.mkdir_p(@dir) unless File.directory?(@dir)
  end

  # Specify the options to use when exporting your fixtures.
  # @param [Hash] opts export configuration options
  # @option opts [Boolean] show_progress whether or not to show the progress bar
  def set_export_options(**opts)
    defaults = { show_progress: true }
    @export_options = defaults.merge(opts)
  end

  # The options to use when exporting your fixtures.
  # @return [Hash] export configuration options
  def export_options
    @export_options ||= set_export_options
  end

  ##
  # Export models to a yml file named after the corresponding table.
  # @param models [Enumerable] an Enumerable containing ActiveRecord models.
  # @param with_references [Array<Symbol>] the associations whose foreign_keys should be replaced with references.
  #
  # Takes an optional block that will be invoked for each model.
  # The block should return a hash of attributes to be merged and
  # saved with the model's attributes.
  # @yield [model] an optional block that will be invoked for each model.
  # @yieldparam model [ActiveRecord::Base] each successive model.
  # @yieldreturn [Hash{String => Object}] a hash of attributes to be merged and saved with the model's attributes.
  def export_fixtures(models, with_references = [])
    return [] unless models.present?

    model_class = models.first.class

    File.open(File.join(@dir, model_class.table_name + '.yml'), 'w') do |file|
      file.write <<~PRELUDE
        _fixture:
          model_class: #{model_class.name}
      PRELUDE

      iterator = export_options[:show_progress] ? ProgressBarIterator : SimpleIterator

      iterator.new(models).each do |model|
        more_attributes = block_given? ? yield(model) : {}
        file.write Fixture.to_yaml(model, with_references, more_attributes)
      end
    end
  end

  class ProgressBarIterator
    def initialize(models)
      @models = models
      @bar = LiveFixtures.get_progress_bar(
        total:models.size,
        title: models.first.class.name
      )
    end

    def each
      @models.each do |model|
        yield model
        @bar.increment
      end
    end
  end

  class SimpleIterator
    def initialize(models)
      @models = models
    end

    def each
      puts @models.first.class.name
      @models.each do |model|
        yield model
      end
    end
  end
end
