require 'spec_helper'

describe LiveFixtures::Import::Fixtures do
  subject(:fixtures) { LiveFixtures::Import::Fixtures.new connection,
                                                          table_name,
                                                          class_name,
                                                          filepath,
                                                          label_to_id }
  let(:connection) { ActiveRecord::Base.connection }
  let(:label_to_id) { {} }
  let(:filepath) { File.join(File.dirname(__FILE__), "../data/live_fixtures/teacher@noredink.com/#{table_name}") }

  describe '#each_table_row_with_label' do
    subject(:yields) do
      [].tap do |yields|
        fixtures.each_table_row_with_label do |value|
          yields << value
        end
      end
    end
    let(:teacher_label) { 'users_2540939' }
    let(:student_one_label) { 'users_2540954' }
    let(:student_two_label) { 'users_2540956' }
    let(:assignment_label) { 'assignments_977909' }
    let(:post_test_label) { 'assignments_978319' }
    let(:course_label) { 'courses_201300' }

    context "which use ERB" do
      let(:table_name) { "users" }
      let(:class_name) { User }
      let(:teacher) { yields.find {|_, label, _| label == teacher_label} }
      let(:teacher_row) { teacher.last }

      it 'evaluates the ERB template' do
        expect( teacher_row['email'] ).to eq 'teacher+1@noredink.com'
      end
    end

    context "which have a has_and_belongs_to_many association of ids" do
      let(:table_name) { 'users' }
      let(:class_name) { 'User' }
      let(:label_to_id) { {teacher_label => 1982} }
      let(:join_table_name) { 'relevant_terms_users' }
      let(:teacher_join_table_rows) do
        yields.select do |table_name, _, row|
          table_name == join_table_name && row['user_id'] == label_to_id[teacher_label]
        end
      end

      it 'produces a row for each record' do
        teacher_join_table_rows.each do |table_name, label, row|
          expect(table_name).to eq join_table_name
          expect(label).to eq LiveFixtures::Import::NO_LABEL
          expect(row['user_id']).to eq 1982
        end

        habtm_ids = teacher_join_table_rows.map { |_, _, row| row['relevant_term_id'].to_i}
        expect(habtm_ids).to contain_exactly(2077,2327)
      end
    end

    context "which have a has_and_belongs_to_many association of labels" do
      let(:table_name) { "assignments" }
      let(:class_name) { 'Assignment' }
      let(:label_to_id) do
        {
            assignment_label => 1941,
            student_one_label => 1942,
            student_two_label => 1982
        }
      end
      let(:join_table_name) { 'assignments_users' }
      let(:join_table_rows) do
        yields.select do |table_name, _, row|
          table_name == join_table_name && row['assignment_id'] == label_to_id[assignment_label]
        end
      end

      it 'produces a row for each record' do
        join_table_rows.each do |table_name, label, row|
          expect(table_name).to eq join_table_name
          expect(label).to eq LiveFixtures::Import::NO_LABEL
          expect(row['assignment_id']).to eq 1941
        end

        habtm_ids = join_table_rows.map { |_, _, row| row['user_id'].to_i}
        expect(habtm_ids).to contain_exactly(1942, 1982)
      end
    end

    context "which reference another fixture using a label" do
      let(:table_name) { "assignments" }
      let(:class_name) { 'Assignment' }
      let(:label_to_id) do
        {
            assignment_label => 1941,
            course_label => 2016
        }
      end
      let(:assignment) { yields.find {|_, label, _| label == assignment_label} }
      let(:assignment_row) { assignment.last }

      it "replaces the association: label with the correct foreign_key_name: pk" do
        expect(assignment_row.key? 'course').to be false
        expect(assignment_row['course_id']).to eq 2016
      end
    end

    context "which use STI and this subclass has an association the other classes don't" do
      let(:table_name) { "assignments" }
      let(:class_name) { 'Assignment' }
      let(:label_to_id) do
        {
            assignment_label => 1941,
            course_label => 2016
        }
      end
      let(:post_test) { yields.find {|_, label, _| label == post_test_label} }
      let(:post_test_row) { post_test.last }

      it "replaces the subclass-specific association: label with the correct foreign_key_name: pk" do
        expect(post_test_row.key? 'previous_test').to be false
        expect(post_test_row['previous_test_id']).to eq 1941
      end
    end
  end
end

def next_username(username)
  match = username.match /^(.+?)(\d*)$/
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
