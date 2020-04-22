FactoryBot.define do
  factory :traveler_room, class: 'Traveler::Room' do
    sport { nil }
    number { "MyText" }
    check_in_date { "2019-06-04" }
    check_out_date { "2019-06-04" }
  end
end
