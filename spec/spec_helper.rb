$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require "active_record"
require 'progressbar'
require 'temping'
require 'live_fixtures'
require 'byebug'

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveSupport::Inflector.inflections do |inflect|
  inflect.plural "cafe", "cafes"
end

Temping.create :flavor do
end

Temping.create :table do
  with_columns do |t|
    t.integer :cafe_id
    t.string :name
    t.string :type
    t.integer :low_chair_id
  end

  has_and_belongs_to_many :dogs
  belongs_to :cafe
end

Temping.create :dogs_tables do
  with_columns do |t|
    t.integer :dog_id
    t.integer :table_id
  end
end

class LowTable < Table; end

Temping.create :cafe do
  with_columns do |t|
    t.string :name
    t.string :pass_code
    t.integer :dog_id
    t.datetime :created_at
    t.integer :license_id
  end

  belongs_to :dog
  has_many :dog_cafes
  has_many :visitors, through: :dog_cafes, source: :dog, class_name: 'Dog'
  has_many :tables
end

Temping.create :dog_cafe do
  with_columns do |t|
    t.integer :dog_id
    t.integer :cafe_id
    t.datetime :created_at
  end

  belongs_to :dog
  belongs_to :cafe
end

Temping.create :dogs_flavors do
  with_columns do |t|
    t.integer :dog_id
    t.integer :flavor_id
  end
end

Temping.create :dog do
  with_columns do |t|
    t.string :email
    t.string :password
    t.string :name
    t.datetime :last_active
  end

  has_and_belongs_to_many :flavors
  has_many :cafes
end
