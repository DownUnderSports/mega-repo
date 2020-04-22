FactoryBot.define do
  factory :traveler_debit, class: 'Traveler::Debit' do
    debit { nil }
    traveler { nil }
    user { nil }
    amount { "" }
  end
end
