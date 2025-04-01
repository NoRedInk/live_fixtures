# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'live_fixtures/version'

Gem::Specification.new do |spec|
  spec.name          = 'live_fixtures'
  spec.version       = LiveFixtures::VERSION
  spec.authors       = ['jleven']
  spec.email         = ['josh@noredink.com']

  spec.required_ruby_version = '>= 3.2'

  spec.summary       = 'Tools for exporting and importing between databases managed by ActiveRecord.'
  spec.license       = 'MIT'

  spec.files = Dir['CHANGELOG.md', 'MIT-LICENSE', 'README.md', 'lib/**/*']
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'activerecord', '>= 7.0', '< 8.0.0'
  spec.add_dependency 'ruby-progressbar'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
