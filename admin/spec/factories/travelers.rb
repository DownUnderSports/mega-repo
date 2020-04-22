FactoryBot.define do
  factory :traveler do
    user { nil }
    team { nil }
    balance { "" }
    shirt_size { "MyText" }
    departing_date { "2018-09-14" }
    departing_from { "MyText" }
    returning_date { "2018-09-14" }
    returning_to { "MyText" }
    bus { "MyText" }
    wristband { "MyText" }
    hotel { "MyText" }
    has_ground_transportation { false }
    has_lodging { false }
    has_gbr { false }
    own_flights { false }
  end
end
