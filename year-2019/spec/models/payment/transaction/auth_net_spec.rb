# frozen_string_literal: true

require 'rails_helper'

test_cards = {
  amex: '370000000000002',
  discover: '6011000000000012',
  master_card: '5424000000000015',
  visa: '4007000000027',
  error: '4222222222222'
}

RSpec.describe Payment::Transaction::AuthNet, type: :model do
  let(:valid_params) do
    {
      amount: '15.0',
      card_number: test_cards[:error],
      cvv: '111',
      expiration_month: '12',
      expiration_year: (Date.today.year + (rand * 10).to_i).to_s[-2..-1],
      billing: {
        street_address: '1755 N 400 E',
        extended_address: 'Ste 201',
        name: 'Test A Payment',
        locality: 'Logan',
        region: 'UT',
        zip: '84341',
        country_code_alpha3: 'USA'
      },
      ip_address: '127.0.0.1',
    }
  end

  let(:record) do
    described_class.new(valid_params)
  end

  describe '#initialize' do
    it 'has required params' do
      [
        :card_number,
        :cvv,
        :expiration_year,
        :expiration_month,
        :billing
      ].each do |k|
        invalid = valid_params.dup
        invalid.delete k
        expect { described_class.new(invalid) }.
        to raise_error ArgumentError, /#{k}/
      end

      expect { described_class.new(valid_params) }.
      to_not raise_error
    end
  end

  describe '#result' do
    it 'calls Gateway#sale' do
      stubbed_gateway = instance_double("#{described_class}::Gateway")
      allow(record).to receive(:gateway) { stubbed_gateway }
      expect(stubbed_gateway).to receive(:sale).
      with(hash_including(
        :amount,
        :card_number,
        :expiration_month,
        :expiration_year,
        :cvv,
        :billing,
        :ip_address,
      )).once do
        {}
      end

      expect(record.result).to eq(record.result)
    end

    it 'returns the result struct from Gateway#sale' do
      expect(record.result).to be_a(Struct)
      expect(record.result).to be_a(described_class::Gateway::RESPONDER)
      expect(record.result).to respond_to(:message)
      expect(record.result).to respond_to(:transaction)
    end
  end

  describe '#payment_attributes' do
    let(:user) { build(:user) }

    it 'returns a hash of attributes to create a payment in the system' do
      expect(record.payment_attributes).to be_a(Hash)
      expect(user.payments.build(record.payment_attributes).valid?).to be true
    end
  end
end
