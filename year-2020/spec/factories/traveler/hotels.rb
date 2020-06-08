FactoryBot.define do
  factory :traveler_hotel, class: 'Traveler::Hotel' do
    name { "MyText" }
    address { nil }
    contacts { "" }
  end
end
