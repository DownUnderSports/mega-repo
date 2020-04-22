FactoryBot.define do
  factory :flight_schedule, class: 'Flight::Schedule' do
    parent_schedule { nil }
    verified_by { nil }
    pnr { "MyText" }
    carrier_pnr { "MyText" }
    amount { "" }
    operator { "MyText" }
    seats_reserved { 1 }
    names_assigned { 1 }
    booking_reference { "MyText" }
    route_summary { "MyText" }
    original_value { "MyText" }
  end
end
