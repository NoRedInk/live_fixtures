# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [0.2.1] - 2017-??-??
### Breaking changes
 - For models with serialized attributes (for storing a ruby object or json blob in a single column, for example), live_fixtures will now use the coder specified in the model definition to dump the value to a string, rather than serializing it to yaml. #10, #11
 - The importer no longer raises an ArgumentError when a yml file for a table listed in `insert_order` cannot be found. Instead, we raise an error if we attempt to replace a label with an ID and cannot find the label yet. This should allow more versatile insert_order lists and also do a better job of ensuring integrity.

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
