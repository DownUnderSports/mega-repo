require 'rails_helper'

RSpec.describe CompetingTeam, type: :model do
  let(:factory_competing_team) { build(:competing_team) }

  it "has a valid factory" do
    expect(factory_competing_team.valid?).to be true
  end

  describe 'Attributes' do
    #   sport_id: :integer, required
    #       name: :text, required
    #     letter: :text, required
    # created_at: :datetime, required
    # updated_at: :datetime, required

    required_column(:competing_team, :sport_id)

    required_column(:competing_team, :name) do
      let(:second_sport) { create(:sport) }

      it "must be unique within a sport scope" do
        expect(record.valid?).to be true
        expect(record.save).to be true

        dupped = record.dup
        expect(dupped.valid?).to be false
        expect(dupped.errors[:name]).to include("has already been taken")
        expect(dupped.save).to be false

        dupped.sport = second_sport
        dupped.valid?
        expect(dupped.errors[:name]).to be_empty

        dupped.sport = record.sport
        record.destroy
        expect(dupped.valid?).to be true
        expect(dupped.save).to be true
        dupped.destroy
      end
    end

    required_column(:competing_team, :letter) do
      let(:second_sport) { create(:sport) }

      it "must be unique within a sport scope" do
        expect(record.valid?).to be true
        expect(record.save).to be true

        dupped = record.dup
        expect(dupped.valid?).to be false
        expect(dupped.errors[:letter]).to include("has already been taken")
        expect(dupped.save).to be false

        dupped.sport = second_sport
        dupped.valid?
        expect(dupped.errors[:letter]).to be_empty

        dupped.sport = record.sport
        record.destroy
        expect(dupped.valid?).to be true
        expect(dupped.save).to be true
        dupped.destroy
      end
    end
  end

  describe 'Associations' do
    it "belongs to a sport" do
      t = described_class.reflect_on_association(:sport)
      expect(t.options[:inverse_of]).to eq(:competing_teams)
      expect(t.options[:required]).to_not eq(false)
      expect(t.options[:optional]).to_not eq(true)
      expect(t.foreign_key.to_sym).to eq(:sport_id)
      expect(t.macro).to eq(:belongs_to)
    end

    it "has many teams" do
      t = described_class.reflect_on_association(:teams)
      expect(t.options[:inverse_of]).to eq(:competing_team)
      expect(t.foreign_key.to_sym).to eq(:competing_team_id)
      expect(t.macro).to eq(:has_many)
    end
  end

end
