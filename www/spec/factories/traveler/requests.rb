FactoryBot.define do
  factory :traveler_request, class: 'Traveler::Request' do
    traveler { nil }
    category { "flight" }
    details { "MyText" }
  end
end
