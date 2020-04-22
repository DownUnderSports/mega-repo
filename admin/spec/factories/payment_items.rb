FactoryBot.define do
  factory :payment_item, class: 'Payment::Item' do
    type { "MyText" }
    payment { nil }
    traveler { nil }
    amount { "" }
    name { "MyText" }
    description { "MyText" }
  end
end
