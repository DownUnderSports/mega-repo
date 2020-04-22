FactoryBot.define do
  factory :athletes_sport do
    athlete
    sport
    rank { 1 }
    stats { "MyText" }
    invited { false }
    positions_array { [] }
  end
end
