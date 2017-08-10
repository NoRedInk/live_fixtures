require 'spec_helper'

describe LiveFixtures::Import::Fixtures do
  subject(:fixtures) { LiveFixtures::Import::Fixtures.new connection,
                                                          table_name,
                                                          class_name,
                                                          filepath,
                                                          label_to_id,
                                                          skip_missing_refs: true }
  let(:connection) { ActiveRecord::Base.connection }
  let(:label_to_id) { {} }
  let(:filepath) { File.join(File.dirname(__FILE__), "../data/live_fixtures/dog_cafes/#{table_name}") }

  describe '#each_table_row_with_label' do
    subject(:yields) do
      [].tap do |yields|
        fixtures.each_table_row_with_label do |value|
          yields << value
        end
      end
    end
    let(:owner_label) { 'dogs_2540939' }
    let(:visitor_one_label) { 'dogs_2540954' }
    let(:visitor_two_label) { 'dogs_2540956' }
    let(:table_label) { 'tables_977909' }
    let(:low_table_label) { 'tables_978319' }
    let(:cafe_label) { 'cafes_201300' }

    context "which use ERB" do
      let(:table_name) { "dogs" }
      let(:class_name) { Dog }
      let(:owner) { yields.find {|_, label, _| label == owner_label} }
      let(:owner_row) { owner.last }

      it 'evaluates the ERB template' do
        expect( owner_row['email'] ).to eq 'wuffy+1@example.com'
      end
    end

    context "which have a has_and_belongs_to_many association of ids" do
      let(:table_name) { 'dogs' }
      let(:class_name) { 'Dog' }
      let(:label_to_id) { {owner_label => 1982} }
      let(:join_table_name) { 'dogs_flavors' }
      let(:owner_join_table_rows) do
        yields.select do |table_name, _, row|
          table_name == join_table_name && row['dog_id'] == label_to_id[owner_label]
        end
      end

      it 'produces a row for each record' do
        owner_join_table_rows.each do |table_name, label, row|
          expect(table_name).to eq join_table_name
          expect(label).to eq LiveFixtures::Import::NO_LABEL
          expect(row['dog_id']).to eq 1982
        end

        habtm_ids = owner_join_table_rows.map { |_, _, row| row['flavor_id'].to_i}
        expect(habtm_ids).to contain_exactly(2077,2327)
      end
    end

    context "which have a has_and_belongs_to_many association of labels" do
      let(:table_name) { "tables" }
      let(:class_name) { 'Table' }
      let(:label_to_id) do
        {
            table_label => 1941,
            visitor_one_label => 1942,
            visitor_two_label => 1982
        }
      end
      let(:join_table_name) { 'dogs_tables' }
      let(:join_table_rows) do
        yields.select do |table_name, _, row|
          table_name == join_table_name && row['table_id'] == label_to_id[table_label]
        end
      end

      it 'produces a row for each record' do
        join_table_rows.each do |table_name, label, row|
          expect(table_name).to eq join_table_name
          expect(label).to eq LiveFixtures::Import::NO_LABEL
          expect(row['table_id']).to eq 1941
        end

        habtm_ids = join_table_rows.map { |_, _, row| row['dog_id'].to_i}
        expect(habtm_ids).to contain_exactly(1942, 1982)
      end
    end

    context "which reference another fixture using a label" do
      let(:table_name) { "tables" }
      let(:class_name) { 'Table' }
      let(:label_to_id) do
        {
            table_label => 1941,
            cafe_label => 2016
        }
      end
      let(:table) { yields.find {|_, label, _| label == table_label} }
      let(:table_row) { table.last }

      it "replaces the association: label with the correct foreign_key_name: pk" do
        expect(table_row.key? 'cafe').to be false
        expect(table_row['cafe_id']).to eq 2016
      end
    end

    context "which use STI and this subclass has an association the other classes don't" do
      let(:table_name) { "tables" }
      let(:class_name) { 'Table' }
      let(:label_to_id) do
        {
            table_label => 1941,
            cafe_label => 2016
        }
      end
      let(:low_table) { yields.find {|_, label, _| label == low_table_label} }
      let(:low_table_row) { low_table.last }

      it "replaces the subclass-specific association: label with the correct foreign_key_name: pk" do
        expect(low_table_row.key? 'low_chair').to be false
        expect(low_table_row['low_chair_id']).to eq 1941
      end
    end
  end
end

def next_dogname(dogname)
  match = dogname.match /^(.+?)(\d*)$/
  base = match[1]
  num  = match[2].to_i
  "#{base}#{num+1}"
end

def next_email(email)
  return random_email unless email
  match = email.match /^(.+?)\+?(\d*)@(.*)$/
  base = match[1]
  num  = match[2].to_i
  dom  = match[3]
  "#{base}+#{num+1}@#{dom}"
end
