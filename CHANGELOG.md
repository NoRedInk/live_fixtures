# Change Log
All notable changes to this project will be documented in this file.
This project adheres to [Semantic Versioning](http://semver.org/).

## [2.1.0] - 2020-12-09
### Added
support for selectively import tables with custom callbacks per table (#34)

## [2.0.0] - 2020-11-11
### Breaking changes
This is a breaking change because LiveFixtures::Import.new now needs to receive the class_names Hash to be able to correctly compute the insert_order in case there are some unconventional class names associations. And the class_names argument is removed from import_all. But this is the only change.

### Added
  - compute insert_order automatically (#33)

## [1.0.1] - 2019-04-10
### Fixed
  - fixed incompatibility with mysql

### Added
  - mysql regression test, confirmation that this gem doesn't work with psotgres

## [1.0.0] - 2019-02-15
### Breaking changes
 - drop support for rails 4.2, ruby < 2.3

### Fixed
 - support for rails 5

### Added
 - None

## [0.3.1] - 2018-03-28
### Breaking changes
 - None

### Fixed
 - None

### Added
 - It is now possible to export an attribute named "id" when it is included among the [additional attributes](https://github.com/NoRedInk/live_fixtures/tree/3868aaddbeb1c0174261673855610c4f8d9e7842#additional-attributes). #25

## [0.3.0] - 2017-08-10
### Breaking changes
 - Imports now raise an error when unable to find a referenced model.
   To avoid this behavior, pass the option `skip_missing_refs: true`. #24

### Fixed
 - For models with serialized attributes (for storing a ruby object or json blob in a single column, for example), live_fixtures will now use the coder specified in the model definition to dump the value to a string, rather than serializing it to yaml. #10, #11

### Added
 - Enhanced documentation #1, #12
 - Options to suppress progress bar output and import errors. #23

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
