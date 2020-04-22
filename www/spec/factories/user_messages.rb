FactoryBot.define do
  factory :user_message, class: 'User::Message' do
    type { "MyText" }
    user
    staff
    category { "MyText" }
    message { "MyText" }
    reviewed { false }
  end
end
