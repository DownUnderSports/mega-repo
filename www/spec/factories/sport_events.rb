FactoryBot.define do
  factory :sport_event, class: 'Sport::Event' do
    sport { nil }
    name { "MyText" }
    pattern { "MyText" }
  end
end
