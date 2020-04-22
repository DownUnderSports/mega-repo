FactoryBot.define do
  factory :flight_leg, class: 'Flight::Leg' do
    schedule { nil }
    flight_number { "MyText" }
    departing_airport { nil }
    departing_at { "2019-05-06 10:42:46" }
    arriving_airport { nil }
    arriving_at { "2019-05-06 10:42:46" }
    is_subsidiary { false }
  end
end
