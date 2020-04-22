FactoryBot.define do
  factory :traveler_bus, class: 'Traveler::Bus' do
    sport { nil }
    color { nil }
    hotel { nil }
    capacity { 1 }
    details { "MyText" }
  end
end
