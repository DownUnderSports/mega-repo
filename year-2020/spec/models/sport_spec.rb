require 'rails_helper'

RSpec.describe Sport, type: :model do
  has_valid_factory(:sport)

  describe 'Attributes' do
    #        abbr: :text, required
    #        full: :text, required
    # abbr_gender: :text, required
    # full_gender: :text, required
    #       title: :text, required
    #  tournament: :text, required
    #  first_year: :integer, required

    [ :abbr, :full ].each do |nm|
      required_column(:sport, nm)
    end

    [ :abbr_gender, :full_gender ].each do |nm|
      required_column(:sport, nm, unique: true)
    end
  end

  describe 'Associations' do
    it 'has one info' do
      t = described_class.reflect_on_association(:info)
      expect(t.options[:inverse_of]).to eq(:sport)
      expect(t.foreign_key.to_sym).to eq(:sport_id)
      expect(t.macro).to eq(:has_one)
    end

    it "has many athletes" do
      t = described_class.reflect_on_association(:athletes)
      expect(t.options[:inverse_of]).to eq(:sport)
      expect(t.foreign_key.to_sym).to eq(:sport_id)
      expect(t.macro).to eq(:has_many)
    end

    it "has many athletes_sports" do
      t = described_class.reflect_on_association(:athletes_sports)
      expect(t.options[:inverse_of]).to eq(:sport)
      expect(t.foreign_key.to_sym).to eq(:sport_id)
      expect(t.macro).to eq(:has_many)
    end

    it "has many competing_teams" do
      t = described_class.reflect_on_association(:competing_teams)
      expect(t.options[:inverse_of]).to eq(:sport)
      expect(t.foreign_key.to_sym).to eq(:sport_id)
      expect(t.macro).to eq(:has_many)
    end

    it "has many possible_athletes through athletes_sports" do
      t = described_class.reflect_on_association(:possible_athletes)
      expect(t.options[:inverse_of]).to eq(:possible_sports)
      expect(t.options[:through]).to eq(:athletes_sports)
      expect(t.options[:source]).to eq(:athlete)
      expect(t.foreign_key.to_sym).to eq(:athlete_id)
      expect(t.macro).to eq(:has_many)
    end

    it "has many teams" do
      t = described_class.reflect_on_association(:teams)
      expect(t.options[:inverse_of]).to eq(:sport)
      expect(t.foreign_key.to_sym).to eq(:sport_id)
      expect(t.macro).to eq(:has_many)
    end
  end
end
