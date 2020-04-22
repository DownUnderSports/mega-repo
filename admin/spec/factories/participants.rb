FactoryBot.define do
  factory :participant do
    name { "MyText" }
    gender { "MyText" }
    state { nil }
    sport { nil }
    school { "MyText" }
    fundraising_time { 1 }
    trip_cost { 1 }
    category { "MyText" }
    year { "MyText" }
  end
end
