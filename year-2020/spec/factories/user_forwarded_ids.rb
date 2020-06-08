FactoryBot.define do
  factory :user_forwarded_id, class: 'User::ForwardedId' do
    original { "MyString" }
    dus_id { "MyString" }
  end
end
