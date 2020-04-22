FactoryBot.define do
  factory :user_ambassador, class: 'User::Ambassador' do
    user { nil }
    ambassador { nil }
    types { "" }
  end
end
