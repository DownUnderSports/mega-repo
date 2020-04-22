FactoryBot.define do
  factory :traveler_marathon_registration, class: 'User::MarathonRegistration' do
    user { nil }
    registered_date { "2019-04-11" }
    confirmation { "MyText" }
    email { "MyText" }
  end
end
