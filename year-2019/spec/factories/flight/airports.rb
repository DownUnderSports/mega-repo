FactoryBot.define do
  factory :flight_airport do
    code { "MyText" }
    name { "MyText" }
    address { nil }
    cost { "" }
    preferred { false }
    carrier { "MyText" }
    selectable { false }
    location { "MyText" }
  end
end
