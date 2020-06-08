require 'rails_helper'

RSpec.describe Address::Variant, type: :model do
  has_valid_factory(:address_variant)

  describe "DB properties" do
  end

  describe 'Attributes' do
    #    address_id: :integer
    # candidate_ids: :integer, required
    #         value: :text, required
    required_column([:address_variant, :without_value_callback], :value, unique: true) do
      let(:variant) { build(:address_variant) }

      it "is set to the serialized value of its normalized address before validation" do
        variant.value = nil
        expect(variant.value).to be_nil
        variant.valid?
        expect(variant.value).to eq Address::Variant.serialize(variant.address.normalize)
      end

      it "overwrites invalid serializations" do
        tmp = "asdf"
        variant.value = tmp
        expect(variant.value).to eq tmp
        variant.valid?
        expect(variant.value).to eq Address::Variant.serialize(variant.address)
      end

      it "leaves valid serializations untouched" do
        expect(variant.value).to_not eq Address::Variant.serialize(variant.address)
        expect(variant.valid?).to be true
        expect(variant.deserialize).to be_truthy
      end
    end
  end

  describe 'Associations' do
    it "belongs to an address" do
      t = described_class.reflect_on_association(:address)
      expect(t.options[:inverse_of]).to eq(:variants)
      expect(t.options[:required]).to_not eq(false)
      expect(t.foreign_key.to_sym).to eq(:address_id)
      expect(t.macro).to eq(:belongs_to)
    end
  end
end
