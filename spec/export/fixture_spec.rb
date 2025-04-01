# frozen_string_literal: true

require 'spec_helper'

describe LiveFixtures::Export::Fixture do
  describe '.to_yaml(model, references = [], more_attributes = {})' do
    subject(:fixture) { YAML.parse(yaml).to_ruby }

    let(:yaml) do
      LiveFixtures::Export::Fixture.to_yaml(model,
                                            references,
                                            more_attributes,
                                            skip_attributes: skip_attributes)
    end
    let(:model) { new_model(table_name, attributes) }
    let(:table_name) { 'tables' }
    let(:attributes) { { 'key' => 'value' } }
    let(:type_for_attribute) { instance_double(ActiveRecord::Type) }
    let(:references) { [] }
    let(:more_attributes) { {} }
    let(:skip_attributes) { [] }

    def new_model(table_name, attributes = {})
      double('Model',
             id: rand(1_000_000),
             class: double(table_name: table_name, type_for_attribute: type_for_attribute),
             attributes: attributes)
    end

    describe 'the label in yaml' do
      subject(:label) { yaml.partition(':').first }

      it { is_expected.to eq "#{table_name}_#{model.id}" }

      context 'for a join table without a primary key' do
        before do
          expect(model).to receive(:id).and_return nil
          expect(SecureRandom).to receive(:uuid).and_return '10-11'
        end

        it 'uses a uuid' do
          expect(subject).to eq "#{table_name}_10_11"
        end
      end
    end

    describe 'when considering the attributes in yaml' do
      # resulting yaml is of the form "<table_name>_<model.id>:\n  <key>: <value>\n\n"
      subject(:yaml_value) { yaml.rpartition(expected_key).last.strip }

      let(:attributes) { { 'key' => value } }
      let(:expected_key) { 'key:' }
      let(:value) { 'butts' }

      it 'does not include the id' do
        expect(subject).not_to match(/id:/)
      end

      shared_examples_for 'a valid encoder for' do |value|
        context "#{value.class.name} and" do
          let(:value) { value }

          it 'produces the correct yaml output' do
            expect(subject).to eq expected_value
          end
        end
      end

      it_behaves_like 'a valid encoder for', Time.now do
        let(:expected_value) { value.utc.to_s(:db) }
      end

      it_behaves_like 'a valid encoder for', DateTime.now do
        let(:expected_value) { value.utc.to_s(:db) }
      end

      it_behaves_like 'a valid encoder for', Date.today do
        let(:expected_value) { value.to_s(:db) }
      end

      it_behaves_like 'a valid encoder for', 1337 do
        let(:expected_value) { value.to_s }
      end

      it_behaves_like 'a valid encoder for', 'hello' => 'butts' do
        let(:expected_value) { value.to_yaml.inspect }
      end

      it_behaves_like 'a valid encoder for', 'butts' do
        let(:expected_value) { value.inspect }
      end

      it_behaves_like 'a valid encoder for',
                      LiveFixtures::Export::Template.new('the template') do
        let(:expected_value) { value.code }
      end

      context 'when a reference is specified' do
        let(:references) { :user }
        let(:attributes) { { 'user_id' => 7 } }
        let(:expected_key) { 'user:' }
        let(:user) { new_model('users') }

        context 'and the model has this reference' do
          before do
            expect(model).to receive(:user).and_return(user)
          end

          it 'overwrites the name of the key' do
            expect(yaml).not_to match(/user_id:/)
            expect(yaml).to     match(/user:/)
          end

          it 'sets the value to a label for the referenced model' do
            expect(subject).to eq "users_#{user.id}"
          end
        end

        context 'but the model does not have that reference' do
          it 'is ignored' do
            expect(yaml).to     match(/user_id:/)
            expect(yaml).not_to match(/user:/)
          end
        end
      end

      context 'when multiple references are specified' do
        let(:references) { %i[user post] }
        let(:attributes) { { 'user_id' => 7, 'post_id' => 9 } }
        let(:user) { new_model('users') }
        let(:post) { new_model('posts') }

        before do
          expect(model).to receive(:user).and_return user
          expect(model).to receive(:post).and_return post
        end

        it 'exports them all' do
          expect(yaml).to match(/user: users_#{user.id}/)
          expect(yaml).to match(/post: posts_#{post.id}/)

          attributes.each_key do |attribute|
            expect(yaml).not_to match(/#{attribute}:/)
          end
        end
      end

      context 'when more_attributes are specified' do
        context "that aren't keys in model.attributes" do
          let(:more_attributes) { { 'more' => 'stuff' } }

          it 'includes them as well' do
            expect(yaml).to match(/key: "butts"/)
            expect(yaml).to match(/more: "stuff"/)
          end
        end

        context 'that are keys in model.attributes' do
          let(:more_attributes) { { 'key' => 'rainbows' } }

          it 'uses the value from more_attributes' do
            expect(yaml).not_to match(/key: "butts"/)
            expect(yaml).to     match(/key: "rainbows"/)
          end
        end

        context 'that include model.id' do
          let(:more_attributes) { { 'id' => model.id } }

          it "includes the model's id" do
            expect(yaml).to match(/key: "butts"/)
            expect(yaml).to match(/id: #{model.id}/)
          end
        end
      end

      context 'when skip_attributes are specified' do
        let(:skip_attributes) { ['key'] }

        it 'does not include them' do
          expect(yaml).not_to match(/key: "butts"/)
        end
      end
    end
  end
end
