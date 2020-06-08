require 'rails_helper'

RSpec.describe State, type: :model do
  has_valid_factory(:state)

  describe 'Attributes' do
    #       abbr: :text, required
    #       full: :text, required
    # conference: :text
    # is_foreign: :boolean, required

    [ :abbr, :full ].each do |nm|
      describe nm do
        let(:record) do
          build(:state)
        end

        it "is required" do
          record.__send__("#{nm}=", nil)
          expect(record.valid?).to be false
          expect(record.errors[nm]).to include("can't be blank")
          expect { record.save(validate: false) }.to raise_error(ActiveRecord::NotNullViolation)
        end

        it "is must be unique" do
          expect(record.valid?).to be true
          expect(record.save).to be true

          dupped = record.dup
          expect(dupped.valid?).to be false
          expect(dupped.errors[nm]).to include("has already been taken")
          expect(dupped.save).to be false

          record.destroy
          expect(dupped.valid?).to be true
          expect(dupped.save).to be true
          dupped.destroy
        end
      end
    end

    describe :conference do
      let(:record) do
        build(:state)
      end

      let(:second_record) do
        build(:state, conference: record.conference)
      end

      it "is optional" do
        record.conference = nil
        expect(record.valid?).to be true
        expect(record.errors[:conference]).to be_empty
        expect { record.save(validate: false) }.to_not raise_error
        record.destroy
      end

      it "is not unique" do
        expect(record.valid?).to be true
        expect(record.save).to be true

        expect(second_record.valid?).to be true
        expect(second_record.errors[:conference]).to be_empty
        expect(second_record.save).to be true
      end
    end

    boolean_column(:state, :is_foreign)
  end

  describe 'Associations' do
    it "has many addresses" do
      t = described_class.reflect_on_association(:addresses)
      expect(t.options[:inverse_of]).to eq(:state)
      expect(t.foreign_key.to_sym).to eq(:state_id)
      expect(t.macro).to eq(:has_many)
    end

    it "has many teams" do
      t = described_class.reflect_on_association(:teams)
      expect(t.options[:inverse_of]).to eq(:state)
      expect(t.foreign_key.to_sym).to eq(:state_id)
      expect(t.macro).to eq(:has_many)
    end
  end
end
