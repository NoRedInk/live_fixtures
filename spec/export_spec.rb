require 'spec_helper'

Temping.create :topic do
  with_columns do |t|
    t.string :name
    t.boolean :premium
  end
end

Temping.create :mastery do
  with_columns do |t|
    t.integer :score
    t.integer :user_id
    t.integer :topic_id
    t.datetime :created_at
  end

  belongs_to :topic
end



describe LiveFixtures::Export do
  class MyExport
    DIR = '/tmp/live_fixtures/export/test'
    include LiveFixtures::Export

    def do_export(masteries)
      set_export_dir DIR

      export_fixtures(masteries, :topic) do |mastery|
        { 'hash' => mastery.hash }
      end

      export_fixtures(masteries.map(&:topic))
    end
  end

  before do
    allow(ProgressBar).to receive(:create).and_return double(increment:nil)
  end

  let(:mastery_file) { StringIO.new }
  let(:topics_file ) { StringIO.new }

  let(:mastery_filepath) { File.join(MyExport::DIR, "masteries.yml") }
  let(:topics_filepath ) { File.join(MyExport::DIR, "topics.yml") }

  context "when exporting nothing" do
    it "never opens a file" do
      expect(File).to_not receive(:write)
      MyExport.new.do_export []
    end
  end

  context "when exporting some Mastery and their Topics" do
    let(:topics) do
      [
        (Topic.create do |t|
           t.name = "Topic 1"
           t.premium = false
         end),
        (Topic.create do |t|
           t.name = "Topic 2"
           t.premium = true
         end),
      ]
    end
    let(:masteries) do
      [
        (Mastery.create do |m|
          m.score = 100
          m.user_id = 7
          m.topic_id = topics.first.id
          m.created_at = Time.now
        end),
        (Mastery.create do |m|
          m.score = 0
          m.user_id = 8
          m.topic_id = topics.last.id
          m.created_at = Time.now
        end),
      ]
    end

    before do
      expect(File).to receive(:open).with(mastery_filepath, 'w').and_yield mastery_file
      expect(File).to receive(:open).with(topics_filepath,  'w').and_yield topics_file

      MyExport.new.do_export masteries
    end

    it "creates the required directory" do
      Dir.exist? MyExport::DIR
    end

    it "produces the expected mastery yaml file" do
      mastery_yaml = masteries.map do |mastery|
        <<-YML
masteries_#{mastery.id}:
  score: #{mastery.score}
  user_id: #{mastery.user_id}
  topic: topics_#{mastery.topic_id}
  created_at: #{mastery.created_at.utc.to_s(:db)}
  hash: #{mastery.hash}

        YML
      end

      expect(mastery_file.string).to eq mastery_yaml.join
    end

    it "produces the expected topics yaml file" do
      topics_yaml = topics.map do |topic|
        <<-YML
topics_#{topic.id}:
  name: "#{topic.name}"
  premium: #{topic.premium}

        YML
      end

      expect(topics_file.string).to eq topics_yaml.join
    end
  end
end
