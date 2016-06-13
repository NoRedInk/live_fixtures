# This module is meant to be `include`ed into your export class.
#
# 1. Call #set_export_dir to set the dir where files should be created.
#    If the dir does not already exist, it will be created for you.
#
# 2. Then call #export_fixtures for each db table, which will produce
#    one yml file for each db table. Do *not* call export_fixtures multiple
#    times for the same db table - that will overwrite the file each time!

module LiveFixtures::Export
  Template  = Struct.new(:code)
  Reference = Struct.new(:name, :value)

  private

  def set_export_dir(dir)
    @dir = dir
    FileUtils.mkdir_p(@dir) unless File.directory?(@dir)
  end

  ##
  # Export models to a yml file named after the corresponding table.
  #
  # Takes an optional block that will be invoked for each model.
  # The block should return a hash of attributes to be merged and
  # saved with the model's attributes.
  def export_fixtures(models, with_references = [])
    return unless models.present?

    table_name = models.first.class.table_name
    File.open(File.join(@dir, table_name + '.yml'), 'w') do |file|

      ProgressBarIterator.new(models).each do |model|
        more_attributes = block_given? ? yield(model) : {}
        file.write Fixture.to_yaml(model, with_references, more_attributes)
      end

    end
  end

  class ProgressBarIterator
    def initialize(models)
      @models = models
      @bar = ProgressBar.create total:models.size,
                                title: models.first.class.name.pluralize,
                                format:'%t: |%B| %P% %E'
    end

    def each
      @models.each do |model|
        yield model
        @bar.increment
      end
    end
  end
end
