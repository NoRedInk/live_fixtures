# frozen_string_literal: true

require 'spec_helper'

describe LiveFixtures::Import::InsertionOrderComputer do
  it 'computes for belongs_to' do
    Temping.create :authors do
      with_columns do |t|
        t.string :name
      end
    end

    Temping.create :books do
      with_columns do |t|
        t.integer :author_id
        t.string :name
      end

      belongs_to :author
    end

    tables = %w[books authors]
    tables.permutation.each do |permutation|
      insert_order = LiveFixtures::Import::InsertionOrderComputer.compute(permutation)
      expect(insert_order).to eq(%w[authors books])
    end
  end

  it 'computes for has_one' do
    Temping.create :supplier do
      with_columns do |t|
        t.string :name
      end

      has_one :account
    end

    Temping.create :account do
      with_columns do |t|
        t.integer :supplier_id
        t.string :account_number
      end
    end

    tables = %w[account supplier]
    tables.permutation.each do |permutation|
      insert_order = LiveFixtures::Import::InsertionOrderComputer.compute(permutation)
      expect(insert_order).to eq(%w[supplier account])
    end
  end

  it 'computes for has_many' do
    Temping.create :xauthors do
      with_columns do |t|
        t.string :name
      end

      has_many :xbooks
    end

    Temping.create :xbooks do
      with_columns do |t|
        t.integer :xauthor_id
        t.string :name
      end
    end

    tables = %w[xbooks xauthors]
    tables.permutation.each do |permutation|
      insert_order = LiveFixtures::Import::InsertionOrderComputer.compute(permutation)
      expect(insert_order).to eq(%w[xauthors xbooks])
    end
  end

  it 'computes for has_many with renamed tables' do
    Temping.create :xyauthors do
      with_columns do |t|
        t.string :name
      end

      has_many :xybooks
    end

    Temping.create :xybooks do
      with_columns do |t|
        t.integer :xyauthor_id
        t.string :name
      end
    end

    tables = %w[books authors]
    class_names = { books: 'Xybook', authors: 'Xyauthor' }

    tables.permutation.each do |permutation|
      insert_order = LiveFixtures::Import::InsertionOrderComputer.compute(permutation, class_names)
      expect(insert_order).to eq(%w[authors books])
    end
  end
end
