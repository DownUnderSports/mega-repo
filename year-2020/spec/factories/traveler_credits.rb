FactoryBot.define do
  factory :traveler_credit, class: 'Traveler::Credit' do
    traveler { nil }
    user { nil }
    amount { "" }
    name { "MyText" }
    description { "MyText" }
  end
end
