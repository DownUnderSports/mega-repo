FactoryBot.define do
  factory :coach do
    school { nil }
    head_coach { nil }
    competing_team { nil }
    checked_background { false }
    deposits { 1 }
    polo_size { "MyText" }
  end
end
