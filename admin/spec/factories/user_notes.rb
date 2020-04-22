FactoryBot.define do
  factory :user_note, class: 'User::Note' do
    user
    staff
    message { "MyText" }
    reviewed { false }
  end
end
