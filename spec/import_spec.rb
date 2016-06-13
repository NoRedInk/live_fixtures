require 'spec_helper'

describe LiveFixtures::Import do
  before do
    allow(ProgressBar).to receive(:create).and_return(
        double(ProgressBar, increment:nil, finished?: nil, finish: nil)
    )
    [2077, 2327, 2321, 1744].each do |id|
      Flavor.create do |rt|
        rt.id = id
      end
    end
  end

  it "creates records in the db as expected" do
    root_path = File.join File.dirname(__FILE__),
                          "data/live_fixtures/dog_cafes/"

    importer = LiveFixtures::Import.new root_path,
      %w{dogs cafes dog_cafes tables}

    expect { importer.import_all }.
      to  change { Dog.count }.by(3).
      and change { DogCafe.count }.by(3).
      and change { Cafe.count }.by(1).
      and change { Table.count }.by(3).
      and change { LowTable.count }.by(1)

    owner = Dog.find_by_email 'wuffy+1@example.com'
    expect( owner ).to be

    cafe = owner.cafes.first
    expect( cafe.name ).to eq "Elm Street Cafe"

    visitors = cafe.visitors.all - [owner]
    expect( visitors.map(&:name) ).
        to contain_exactly("jgiraffe1", "kchameleon1")

    tables = cafe.tables.all
    expect( tables.map(&:name) ).
        to contain_exactly(
               "Meadow",
               "River",
               "Riverbank"
           )

    low_table = LowTable.where(cafe_id: cafe).first
    expect( low_table.name ).to eq "River"

    tables.each do |table|
      expect( table.dogs ).to contain_exactly(*visitors)
    end

    expect( owner.flavors.map(&:id) ).
        to contain_exactly(2077, 2327)

    expect( visitors.flat_map(&:flavors).map(&:id) ).
        to contain_exactly(2321, 2077, 1744)
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

def unique_pass_code
  Digest::MD5.hexdigest(Time.now.to_f.to_s + rand.to_s)[rand(23), 8]
end
