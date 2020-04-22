require 'rails_helper'

RSpec.describe Source, type: :model do
  let(:factory_source) { build(:source) }

  it "has a valid factory" do
    expect(factory_source.valid?).to be true
  end

  describe 'Attributes' do
    # name: :text, required

    required_column(:source, :name, unique: true)
  end

  describe 'Associations' do
    it "has many athletes" do
      t = described_class.reflect_on_association(:athletes)
      expect(t.options[:inverse_of]).to eq(:source)
      expect(t.foreign_key.to_sym).to eq(:source_id)
      expect(t.macro).to eq(:has_many)
    end
  end
end
