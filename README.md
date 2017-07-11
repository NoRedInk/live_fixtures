# LiveFixtures

ActiveRecord::Fixtures are a powerful way of populating data in a db;
however, its strategy for handling primary keys and associations is
UNACCEPTABLE for use with a production db. LiveFixtures works around this.

## Installation

Add this line to your application's Gemfile:

    gem 'live_fixtures'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install live_fixtures

## Usage

### Exporting

The `LiveFixtures::Export` module is meant to be included into your export class.


    class Export::User
      include LiveFixtures::Export

      def export(user_id)
        set_export_dir "#{Rails.root}/data/export/user/#{user_id}/"

        export_user_and_posts(user_id)
      end

      def export_user_and_posts(user_id)
        user = User.find(user_id)
        export_fixtures([user])

        export_fixtures user.posts, :user do |post|
          { "likes" => post.likes.count,
            "unique_url" => Template.new("<%= Export::Helper.unique_url %>") }
        end
      end
    end


1. Call #set_export_dir to set the dir where files should be created.
   If the dir does not already exist, it will be created for you.

2. Then call #export_fixtures for each db table, which will produce
   one yml file for each db table. Do *not* call export_fixtures multiple
   times for the same db table - that will overwrite the file each time!

3. For advanced usage, read the sections about Additional Attributes, References, and Templates.

### Importing

The `LiveFixtures::Import` class allows you to specify the location of your fixtures and the order in which to import them. Once you've done that, you can import them directly to your database.


    module Seed::User
      def self.from_fixtures(fixtures_directory)
        insert_order = %w{users posts}

        importer = LiveFixtures::Import.new fixtures_directory, insert_order
        importer.import_all
      end
    end


## Motivation

ActiveRecord::Fixtures is designed to import data into a test database, and its practices of truncating tables and randomly generating primary keys work well in that setting.

LiveFixtures is designed for importing data into a production database, where we cannot truncate the tables and where inserting records with randomly generated primary keys will cause collisions and waste space.

### Here's how ActiveRecord::Fixtures work

Each record is assigned a label in its yml file. Primary key values are
assigned using a guid algorithm that maps a label to a consistent integer
between 1 and 2^30-1. Primary keys can then be assigned before saving any
records to the db.

Why would they do this? Because, this enables us to use labels in the
Fixture yml files to refer to associations. For example:

      <users.yml>
      bob:
        username: thebob

      <posts.yml>
      hello:
        message: Hello everyone!
        user: bob



The ActiveRecord::Fixture system first converts every instance of `bob` and
`hello` into an integer using ActiveRecord::Fixture#identify, and then can
save the records IN ANY ORDER and know that all foreign keys will be valid.

There is a big problem with this. In a test db, each table is empty and so the
odds of inserting a few dozen records causing a primary key collision is
very small. However, for a production table with a hundred million rows, this
is no longer the case! Collisions abound and db insertion fails.

Also, auto-increment primary keys will continue from the LARGEST existing
primary key value. If we insert a record at 1,000,000,000 - we've reduced the
total number of records we can store in that table in half. Fine for a test db
but not ideal for production.


### LiveFixtures work differently

Since we want to be able to take advantage of normal auto-increment behavior,
we cannot know the primary keys of each record before saving it to the db.
Instead, we save each record, and then maintain a mapping (`@label_to_id`)
from that record's label (`bob`), to its primary key (`213`). Later, when
another record (`hello`) references `bob`, we can use this mapping to look up
the primary key for `bob` before saving `hello`.

This means that the order we insert records into the db matters: `bob` must
be inserted before `hello`! This order is defined in INSERT_ORDER, and
reflected in the order of the `@table_names` array.


## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/live_fixtures. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
