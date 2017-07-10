require 'spec_helper'

Temping.create :trick do
  with_columns do |t|
    t.string :name
    t.text :prerequisites
    t.boolean :frisbee
  end

  serialize :prerequisites, JSON
end

Temping.create :level do
  with_columns do |t|
    t.integer :score
    t.integer :dog_id
    t.integer :trick_id
    t.datetime :created_at
  end

  belongs_to :trick
end



describe LiveFixtures::Export do
  class MyExport
    DIR = '/tmp/live_fixtures/export/test'
    include LiveFixtures::Export

    def do_export(levels)
      set_export_dir DIR

      export_fixtures(levels, :trick) do |level|
        { 'hash' => level.hash }
      end

      export_fixtures(levels.map(&:trick))
    end
  end

  before do
    allow(ProgressBar).to receive(:create).and_return double(increment:nil)
  end

  let(:level_file) { StringIO.new }
  let(:tricks_file ) { StringIO.new }

  let(:level_filepath) { File.join(MyExport::DIR, "levels.yml") }
  let(:tricks_filepath ) { File.join(MyExport::DIR, "tricks.yml") }

  context "when exporting nothing" do
    it "never opens a file" do
      expect(File).to_not receive(:write)
      MyExport.new.do_export []
    end
  end

  context "when exporting some Level and their Tricks" do
    let(:tricks) do
      [
        (Trick.create do |t|
           t.name = "Trick 1"
           t.prerequisites = {}
           t.frisbee = false
         end),
        (Trick.create do |t|
           t.name = "Trick 2"
           t.prerequisites = {trick: "Trick 1"}
           t.frisbee = true
         end),
      ]
    end
    let(:levels) do
      [
        (Level.create do |m|
          m.score = 100
          m.dog_id = 7
          m.trick_id = tricks.first.id
          m.created_at = Time.now
        end),
        (Level.create do |m|
          m.score = 0
          m.dog_id = 8
          m.trick_id = tricks.last.id
          m.created_at = Time.now
        end),
      ]
    end

    before do
      expect(File).to receive(:open).with(level_filepath, 'w').and_yield level_file
      expect(File).to receive(:open).with(tricks_filepath,  'w').and_yield tricks_file

      MyExport.new.do_export levels
    end

    it "creates the required directory" do
      Dir.exist? MyExport::DIR
    end

    it "produces the expected level yaml file" do
      level_yaml = levels.map do |level|
        <<-YML
levels_#{level.id}:
  score: #{level.score}
  dog_id: #{level.dog_id}
  trick: tricks_#{level.trick_id}
  created_at: #{level.created_at.utc.to_s(:db)}
  hash: #{level.hash}

        YML
      end

      expect(level_file.string).to eq level_yaml.join
    end

    it "produces the expected tricks yaml file" do
      tricks_yaml = tricks.map do |trick|
        <<-YML
tricks_#{trick.id}:
  name: "#{trick.name}"
  prerequisites: >-
    #{trick.prerequisites.to_json}
  frisbee: #{trick.frisbee}

        YML
      end

      expect(tricks_file.string).to eq tricks_yaml.join
    end
  end
end
