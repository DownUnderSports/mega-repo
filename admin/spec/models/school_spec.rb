require 'rails_helper'

RSpec.describe School, type: :model do
  has_valid_factory(:school)

  describe 'Attributes' do
    #          pid: :text, required
    #   address_id: :integer
    #         name: :text, required
    #      allowed: :boolean, required
    # allowed_home: :boolean, required
    #       closed: :boolean, required
    #   created_at: :datetime, required
    #   updated_at: :datetime, required

    required_column(:school, :pid, unique: true)

    required_column(:school, :name) do
      let(:second_address) { create(:pre_verified_address) }

      it "must be unique within an address scope" do
        expect(record.valid?).to be true
        expect(record.save).to be true

        dupped = record.dup
        dupped.pid = rand
        expect(dupped.valid?).to be false
        expect(dupped.errors[:name]).to include("has already been taken")
        expect(dupped.save).to be false

        dupped.address = second_address

        expect(dupped.valid?).to be true
        expect(dupped.save).to be true

        dupped.address = record.address
        record.destroy
        expect(dupped.valid?).to be true
        expect(dupped.save).to be true
        dupped.destroy
      end
    end

    [ :allowed, :allowed_home, :closed ].each do |nm|
      boolean_column(:school, nm, default: (nm == :closed) ? false : true)
    end
  end

  describe 'Associations' do
    it "belongs to an address" do
      t = described_class.reflect_on_association(:address)
      expect(t.options[:inverse_of]).to eq(:schools)
      expect(t.options[:required]).to_not eq(false)
      expect(t.foreign_key.to_sym).to eq(:address_id)
      expect(t.macro).to eq(:belongs_to)
    end

    it "has many athletes" do
      t = described_class.reflect_on_association(:athletes)
      expect(t.options[:inverse_of]).to eq(:school)
      expect(t.foreign_key.to_sym).to eq(:school_id)
      expect(t.macro).to eq(:has_many)
    end
  end
end
