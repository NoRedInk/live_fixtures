# LiveFixtures

Like ActiveRecord::Fixtures, but for production.

> A test fixture is a fixed state of a set of objects used as a baseline for running tests.
> The purpose of a test fixture is to ensure that there is a well known and fixed environment in which tests are run so that results are repeatable.
>
> [https://github.com/junit-team/junit4/wiki/test-fixtures](https://github.com/junit-team/junit4/wiki/test-fixtures)

[ActiveRecord::Fixtures](http://api.rubyonrails.org/classes/ActiveRecord/FixtureSet.html) provide a powerful way to populate a database with test fixtures, but its strategy for handling primary keys and associations is not intended for use with a production db.

LiveFixtures uses a different strategy that means it is safer to use in a live environment.

For more information, see [the motivation section below](#motivation).

## Compatibility
LiveFixtures is tested against Sqlite3 & mysql. It is known to be incompatible with postgres.

## Installation

Add this line to your application's Gemfile:

    gem 'live_fixtures'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install live_fixtures

## Usage

This gem provides functionality for both the export and the import of fixtures.

While they work nicely together, it is also possible to import manually generated fixtures.

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

3. You can optionally call #set_export_options, passing {show_progress: false}
   if you'd like to disable the progress bar.

4. For advanced usage, read the sections about Additional Attributes, References, and Templates.

### Importing

The `LiveFixtures::Import` class allows you to specify the location of your fixtures and the order in which to import them. Once you've done that, you can import them directly to your database.


    module Seed::User
      def self.from_fixtures(fixtures_directory)
        insert_order = %w{users posts}

        importer = LiveFixtures::Import.new fixtures_directory, insert_order
        importer.import_all
      end
    end

Options may be passed when initializing an importer as follow:
 - show_progress: defaults to true.
   Pass false to disable the progress bar output.
 - skip_missing_tables: defaults to false.
   Pass true to avoid raising an error when a table listed in insert_order has
   no yml file.
 - skip_missing_refs: defaults to false.
   Pass false to raise an error when the importer is unable to re-establish a
   relation.

## Advanced Usage

The following topics reference this schema and exporter:

    class User < ActiveRecord::Base
      has_many :posts
    end

    class Post < ActiveRecord::Base
      belongs_to :user
      has_and_belongs_to_many :channels
    end

    class Channel < ActiveRecord::Base
      has_and_belongs_to_many :users
    end

    class YourExporter
      include LiveFixtures::Export
      def initialize(fixture_path)
        set_export_dir fixture_path
      end

      def export_models(models, references = [], &additional_attributes)
        export_fixtures(models, references, &additional_attributes)
      end
    end

### Additional Attributes

We can use a block to add more attributes to a fixture. Each model is passed to the block as an argument, and the block should return a hash of additional arguments.

    dev_ops_posts = Post.where(topic: "Dev Ops")
    exporter = YourExporter.new("fixtures/")
    exporter.export_models(dev_ops_posts) do |post|
      { summary: PostSummarizer.summarize(post) }
    end

    # In our fixtures/posts.yml file
    posts_1234:
      ...
      user_id: 5678
      summary: "Dev ops is cool."

### References

References allow fixtures to capture a model's associations, so they can be correctly re-established on import.

When we export a fixture for a post above, we'd expect to see an attribute `user_id`

    post = Post.find(1234)
    post.user_id = 5678
    post.save!
    exporter = YourExporter.new("fixtures/")
    exporter.export_models([post])

    # In our posts.yml file
    posts_1234:
      ...
      user_id: 5678


If we import this post, it will still have 5678 for its user_id foreign key. This may or may not be the desired outcome.

If we pass `:user` as references, LiveFixtures will replace the foreign key with a reference, so that the association can be correctly re-established on import:

    post = Post.find(1234)
    post.user_id = 5678
    post.save!
    exporter = YourExporter.new("fixtures/")
    exporter.export_models([post], :user)
    exporter.export_models([post.user])

    # In our posts.yml file
    posts_1234:
      ...
      user: users_5678

    # In our users.yml file
    users_5678:
      ...

When we import these fixtures using the correct `insert_order` (`['users', 'posts']`), the newly imported post will belong to the newly imported user, no matter what their new ids are.

Currently, this works for belongs_to and has_and_belongs_to_many associations.

For has_and_belongs_to_many relation, add a field to one of the records, and the import will populate the join table.

The formatting of the fixture is quite flexible, and the value for this field can be either a list or comma-separated string containing either references or IDs of the associated records. In all cases, though, the value should match the association name. Note that in all cases below the key is `channels` and not `channel_ids`:

    # In our users.yml file
    users_5678:
      channels: "1,2,3"

    users_1234:
      channels:
        - channel_1
        - bobs_cool_channel

    # In our channels.yml file
    channel_1:
      ...

    bobs_cool_channel:
      ...

Also note it's not necessary to format your references the way the exporter does - `bobs_cool_channel` is a totally valid reference.

### Templates

Templates allow you to export fixtures containing erb, that will be evaluated at the time of fixture import.

    posts = Post.where(user_id: 5678
    exporter = YourExporter.new("fixtures/")
    exporter.export_models([post]) do |post|
      { unique_promo_code: Template.new("<%= PromoCodeGenerator.unique_promo_code(#{post.id}) %>")
    end

    # In our fixtures/posts.yml file
    posts_1234:
      ...
      user_id: 5678
      unique_promo_code: <%= PromoCodeGenerator.unique_promo_code(1234) %>

In the example above, we'd be able to generate a new unique promo code for each post as we import them.


## Motivation

One particular challenge when working with fixtures is describing associations between records. When they're in the database, records have unique primary keys, and associations are captured using foreign keys (references to the associated record's primary key). For example, a row in the `posts` table may have a column `user_id`. If it's value is `1234`, it indicated that `Post` belongs to the `User` with id `1234`.

How can we model associations when fixtures are removed from the database? It's not enough to just serialize the foreign keys, as we expect each record to have a different primary key each time it is imported into a database.

ActiveRecord::Fixtures answers this question in a way that is very effective for a test database, but that is not safe for a live database.

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

Please remember to update the docs on your PR if you change anything. You can see the YARD docs live while you change them by running `yard server --reload`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/NoRedInk/live_fixtures. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.


## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
