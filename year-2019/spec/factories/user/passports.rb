FactoryBot.define do
  factory :user_passport, class: 'User::Passport' do
    user { nil }
    checker { nil }
    second_checker { nil }
    category { "MyText" }
    code { "MyText" }
    number { "MyText" }
    surname { "MyText" }
    given_names { "MyText" }
    nationality { "MyText" }
    sex { "" }
    authority { "MyText" }
    birth_date { "2019-04-03" }
    country_of_birth { "MyText" }
    citizenships_array { "MyText" }
    aliases_array { "MyString" }
    has_convictions { false }
    convictions_array { "MyText" }
    issued_date { "2019-04-03" }
    expiration_date { "2019-04-03" }
    eta_email_date { "2019-04-03" }
  end
end
