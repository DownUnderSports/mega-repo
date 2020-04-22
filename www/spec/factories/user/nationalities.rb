FactoryBot.define do
  factory :user_nationality, class: 'User::Nationality' do
    code { "MyText" }
    country { "MyText" }
    nationality { "MyText" }
    visable { false }
  end
end
