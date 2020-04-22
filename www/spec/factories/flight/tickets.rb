FactoryBot.define do
  factory :flight_ticket, class: 'Flight::Ticket' do
    schedule { nil }
    user { nil }
    ticketed { false }
    required { false }
    ticket_number { "MyText" }
  end
end
