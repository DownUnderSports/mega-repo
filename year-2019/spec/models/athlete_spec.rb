require 'rails_helper'

RSpec.describe Athlete, type: :model do
  has_valid_factory(:athlete)

  describe 'Attributes' do
    #            full_name: :text
    #            school_id: :integer
    #            source_id: :integer
    #             sport_id: :integer
    #    competing_team_id: :integer
    #                 grad: :integer
    #    student_list_date: :date
    #         respond_date: :date
    # original_school_name: :text
    #           created_at: :datetime, required
    #           updated_at: :datetime, required

    optional_column(:athlete, :full_name)
  end

  describe 'Associations' do
    it "belongs to a school" do
      t = described_class.reflect_on_association(:school)
      expect(t.options[:inverse_of]).to eq(:athletes)
      expect(t.options[:required]).to_not eq(false)
      expect(t.options[:optional]).to_not eq(true)
      expect(t.foreign_key.to_sym).to eq(:school_id)
      expect(t.macro).to eq(:belongs_to)
    end

    it "belongs to a source" do
      t = described_class.reflect_on_association(:source)
      expect(t.options[:inverse_of]).to eq(:athletes)
      expect(t.options[:required]).to_not eq(false)
      expect(t.options[:optional]).to_not eq(true)
      expect(t.foreign_key.to_sym).to eq(:source_id)
      expect(t.macro).to eq(:belongs_to)
    end

    it "belongs to a sport" do
      t = described_class.reflect_on_association(:sport)
      expect(t.options[:inverse_of]).to eq(:athletes)
      expect(t.options[:optional]).to eq(true)
      expect(t.options[:required]).to_not eq(true)
      expect(t.foreign_key.to_sym).to eq(:sport_id)
      expect(t.macro).to eq(:belongs_to)
    end

    it "belongs to a student_list" do
      t = described_class.reflect_on_association(:student_list)
      expect(t.options[:inverse_of]).to eq(:athletes)
      expect(t.options[:optional]).to eq(true)
      expect(t.options[:required]).to_not eq(true)
      expect(t.options[:primary_key]).to eq(:sent)
      expect(t.options[:foreign_key]).to eq(:student_list_date)
      expect(t.foreign_key.to_sym).to eq(:student_list_date)
      expect(t.macro).to eq(:belongs_to)
    end

    it "has many athletes_sports" do
      t = described_class.reflect_on_association(:athletes_sports)
      expect(t.options[:inverse_of]).to eq(:athlete)
      expect(t.foreign_key.to_sym).to eq(:athlete_id)
      expect(t.macro).to eq(:has_many)
    end

    it "has many sports through athletes_sports" do
      t = described_class.reflect_on_association(:possible_sports)
      expect(t.options[:inverse_of]).to eq(:possible_athletes)
      expect(t.options[:through]).to eq(:athletes_sports)
      expect(t.options[:source]).to eq(:sport)
      expect(t.foreign_key.to_sym).to eq(:sport_id)
      expect(t.macro).to eq(:has_many)
    end
  end
end
