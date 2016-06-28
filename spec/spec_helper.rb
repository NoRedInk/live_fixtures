$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)

require "active_record"
require 'ruby-progressbar'
require 'temping'
require 'live_fixtures'
require 'byebug'

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false

Temping.create :relevant_term do
end

Temping.create :assignment do
  with_columns do |t|
    t.integer :course_id
    t.string :name
    t.string :correctness
    t.string :type
    t.integer :previous_test_id
  end

  has_and_belongs_to_many :users
  belongs_to :course
end

Temping.create :assignments_users do
  with_columns do |t|
    t.integer :user_id
    t.integer :assignment_id
  end
end

class QuizPostTest < Assignment; end

Temping.create :course do
  with_columns do |t|
    t.string :name
    t.string :invite_code
    t.integer :user_id
    t.datetime :created_at
    t.integer :premium_license_id
  end

  belongs_to :user
  has_many :user_courses
  has_many :students, through: :user_courses, source: :user, class_name: 'User'
  has_many :assignments
end

Temping.create :user_course do
  with_columns do |t|
    t.integer :user_id
    t.integer :course_id
    t.datetime :join_date
  end

  belongs_to :user
  belongs_to :course
end

Temping.create :relevant_terms_users do
  with_columns do |t|
    t.integer :user_id
    t.integer :relevant_term_id
  end
end

Temping.create :user do
  with_columns do |t|
    t.string :email
    t.string :password
    t.string :username
    t.datetime :last_login
  end

  has_and_belongs_to_many :relevant_terms
  has_many :courses
end
