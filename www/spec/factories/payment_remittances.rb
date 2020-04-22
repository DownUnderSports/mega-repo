FactoryBot.define do
  factory :payment_remittance, class: 'Payment::Remittance' do
    remit_number { "MyText" }
    recorded { false }
    reconciled { false }
  end
end
