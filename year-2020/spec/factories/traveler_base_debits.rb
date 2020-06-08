FactoryBot.define do
  factory :traveler_base_debit, class: 'Traveler::BaseDebit' do
    amount { "" }
    name { "MyText" }
    description { "MyText" }
    is_default { false }
  end
end
