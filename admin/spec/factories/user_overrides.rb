FactoryBot.define do
  factory :user_override, class: 'User::Override' do
    user { nil }
    payment_description { "MyText" }
  end
end
