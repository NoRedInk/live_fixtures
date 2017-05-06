# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'live_fixtures/version'

Gem::Specification.new do |spec|
  spec.name          = "live_fixtures"
  spec.version       = LiveFixtures::VERSION
  spec.authors       = ["jleven"]
  spec.email         = ["josh@noredink.com"]

  spec.summary       = %q{Tools for exporting and importing between databases managed by ActiveRecord.}
  spec.license       = "MIT"

  spec.files         =  Dir['CHANGELOG.md', 'MIT-LICENSE', 'README.md', 'lib/**/*']
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "activerecord", "~> 4.2"
  spec.add_dependency "ruby-progressbar"
  spec.add_development_dependency "bundler", "~> 1.11"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "temping", "~> 3.0"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency "sqlite3"
end
