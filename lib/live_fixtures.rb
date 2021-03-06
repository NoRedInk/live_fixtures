require "live_fixtures/version"
require "live_fixtures/import"
require "live_fixtures/import/fixtures"
require "live_fixtures/import/insertion_order_computer"
require "live_fixtures/export"
require "live_fixtures/export/fixture"
require "ruby-progressbar"
require "yaml"

module LiveFixtures
  module_function
  def get_progress_bar total:, title:
    ProgressBar.create(
      total: total,
      title: title,
      format:'%t: |%B| %P% %E',
      throttle_rate: 0.1
    )
  end
end
