require 'rails_helper'

RSpec.describe StudentList, type: :model do
  let(:factory_student_list) { build(:student_list) }

  it "has a valid factory" do
    expect(factory_student_list.valid?).to be true
  end

  describe 'Attributes' do
    #     sent: :date, required
    # received: :date

    required_column(:student_list, :sent, unique: true)
  end

  describe 'Associations' do
    it "has many addresses" do
      t = described_class.reflect_on_association(:addresses)
      expect(t.options[:inverse_of]).to eq(:student_list)
      expect(t.foreign_key.to_sym).to eq(:student_list_id)
      expect(t.macro).to eq(:has_many)
    end

    it "has many athletes" do
      t = described_class.reflect_on_association(:athletes)
      expect(t.options[:inverse_of]).to eq(:student_list)
      expect(t.options[:foreign_key]).to eq(:student_list_date)
      expect(t.options[:primary_key]).to eq(:sent)
      expect(t.foreign_key.to_sym).to eq(:student_list_date)
      expect(t.macro).to eq(:has_many)
    end
  end
end
