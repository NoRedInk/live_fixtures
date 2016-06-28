require "live_fixtures/version"
require "live_fixtures/import"
require "live_fixtures/import/fixtures"
require "live_fixtures/export"
require "live_fixtures/export/fixture"
require "ruby-progressbar"

module LiveFixtures
  module_function
  def get_progress_bar total:, title:
    ProgressBar.create(
      total: total,
      title: title,
      format:'%t: |%B| %P% %E'
    )
  end
end
