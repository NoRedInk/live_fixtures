# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [0.2.1] - 2017-??-??
### Fixed
 - For models with serialized attributes (for storing a ruby object or json blob in a single column, for example), live_fixtures will now use the coder specified in the model definition to dump the value to a string, rather than serializing it to yaml. #10, #11

### Added
 - Enhanced documentation #1, #12

## [0.2.0] - 2017-05-09
### Breaking change
- live_fixtures now depends on activerecord ~> 4.2

[0.2.0]: https://github.com/NoRedInk/live_fixtures/compare/v0.1.1...v0.2.0

## [0.1.1] - 2016-06-30
### Fixed
- [live fixtures works better with slow TTYs & zeus](https://github.com/NoRedInk/live_fixtures/pull/4)

[0.1.1]: https://github.com/NoRedInk/live_fixtures/compare/v0.1.0...v0.1.1

## 0.1.0 - 2016-06-13
### Added
- initial release
