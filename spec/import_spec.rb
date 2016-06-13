require 'spec_helper'

describe LiveFixtures::Import do
  before do
    allow(ProgressBar).to receive(:create).and_return(
        double(ProgressBar, increment:nil, finished?: nil, finish: nil)
    )
    [2077, 2327, 2321, 1744].each do |id|
      RelevantTerm.create do |rt|
        rt.id = id
      end
    end
  end

  it "creates records in the db as expected" do
    root_path = File.join File.dirname(__FILE__),
                          "data/live_fixtures/teacher@noredink.com/"

    importer = LiveFixtures::Import.new root_path,
                                        %w{users courses user_courses assignments}

    expect { importer.import_all }.
      to  change {         User.count }.by(3).
      and change {   UserCourse.count }.by(3).
      and change {       Course.count }.by(1).
      and change {   Assignment.count }.by(3).
      and change { QuizPostTest.count }.by(1)

    teacher = User.find_by_email 'teacher+1@noredink.com'
    expect( teacher ).to be

    course = teacher.courses.first
    expect( course.name ).to eq "Honors English 7"

    students = course.students.all - [teacher]
    expect( students.map(&:username) ).
        to contain_exactly("jgiraffe1", "kchameleon1")

    assignments = course.assignments.all
    expect( assignments.map(&:name) ).
        to contain_exactly(
               "Pre-Test: Adjectives vs. Adverbs",
               "Post-Test: Adjectives vs. Adverbs",
               "Comma Splices, Fragments, and Run-Ons"
           )

    post_test = QuizPostTest.where(course_id: course).first
    expect( post_test.name ).to eq "Post-Test: Adjectives vs. Adverbs"

    assignments.each do |assignment|
      expect( assignment.users ).to contain_exactly(*students)
    end

    expect( teacher.relevant_terms.map(&:id) ).
        to contain_exactly(2077, 2327)

    expect( students.flat_map(&:relevant_terms).map(&:id) ).
        to contain_exactly(2321, 2077, 1744)
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

def unique_invite_code
  Digest::MD5.hexdigest(Time.now.to_f.to_s + rand.to_s)[rand(23), 8]
end
