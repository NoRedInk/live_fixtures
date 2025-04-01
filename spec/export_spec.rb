# frozen_string_literal: true

require 'spec_helper'

Temping.create :trick do
  with_columns do |t|
    t.string :name
    t.text :prerequisites
    t.text :instructions
    t.boolean :frisbee
  end

  serialize :prerequisites, coder: JSON
  serialize :instructions
end

Temping.create :level do
  with_columns do |t|
    t.integer :score
    t.integer :dog_id
    t.integer :trick_id
    t.text :rubric
    t.integer :ignore
    t.datetime :created_at
  end

  belongs_to :trick

  serialize :rubric
end

describe LiveFixtures::Export do
  class MyExport
    DIR = '/tmp/live_fixtures/export/test'
    include LiveFixtures::Export

    def do_export(levels)
      set_export_dir DIR

      export_fixtures(levels, :trick, skip_attributes: ['ignore']) do |level|
        { 'hash' => level.hash,
          'rubric' => level.rubric.to_yaml }
      end

      export_fixtures(levels.map(&:trick))
    end
  end

  before do
    allow(ProgressBar).to receive(:create).and_return double(increment: nil)
  end

  let(:level_file) { StringIO.new }
  let(:tricks_file) { StringIO.new }

  let(:level_filepath) { File.join(MyExport::DIR, 'levels.yml') }
  let(:tricks_filepath) { File.join(MyExport::DIR, 'tricks.yml') }

  context 'when exporting nothing' do
    it 'never opens a file' do
      expect(File).not_to receive(:write)
      MyExport.new.do_export []
    end

    it 'returns an empty array' do
      expect(MyExport.new.do_export([])).to eq([])
    end
  end

  context 'when exporting some Level and their Tricks' do
    let(:tricks) do
      [
        (Trick.create do |t|
           t.name = 'Trick 1'
           t.prerequisites = {}
           t.instructions = %w[Sit Shake Sit]
           t.frisbee = false
         end),
        (Trick.create do |t|
           t.name = 'Trick 2'
           t.prerequisites = { trick: 'Trick 1' }
           t.instructions = []
           t.frisbee = true
         end)
      ]
    end
    let(:levels) do
      [
        (Level.create do |m|
          m.score = 100
          m.dog_id = 7
          m.trick_id = tricks.first.id
          m.rubric = { pizzaz: 2, shininess: 4 }
          m.ignore = 1
          m.created_at = Time.now
        end),
        (Level.create do |m|
          m.score = 0
          m.dog_id = 8
          m.trick_id = tricks.last.id
          m.rubric = {}
          m.created_at = Time.now
        end)
      ]
    end

    before do
      expect(File).to receive(:open).with(level_filepath, 'w').and_yield level_file
      expect(File).to receive(:open).with(tricks_filepath, 'w').and_yield tricks_file

      MyExport.new.do_export levels
    end

    it 'creates the required directory' do
      Dir.exist? MyExport::DIR
    end

    it 'produces the expected level yaml file' do
      yaml_header =
        <<~YAML
          _fixture:
            model_class: Level
        YAML

      level_yaml = levels.map do |level|
        <<~YML
          levels_#{level.id}:
            score: #{level.score}
            dog_id: #{level.dog_id}
            trick: tricks_#{level.trick_id}
            rubric: |-
          #{level.rubric.to_yaml.indent(4)}
            created_at: #{level.created_at.utc.to_fs(:db)}
            hash: #{level.hash}

        YML
      end

      expect(level_file.string).to eq(yaml_header + level_yaml.join)
    end

    it 'produces the expected tricks yaml file' do
      yaml_header =
        <<~YAML
          _fixture:
            model_class: Trick
        YAML

      tricks_yaml = tricks.map do |trick|
        <<~YML
          tricks_#{trick.id}:
            name: "#{trick.name}"
            prerequisites: |-
          #{trick.prerequisites.to_json.indent(4)}
            instructions: |-
          #{trick.instructions.to_yaml.indent(4)}
            frisbee: #{trick.frisbee}

        YML
      end

      expect(tricks_file.string).to eq(yaml_header + tricks_yaml.join)
    end
  end
end
