FactoryBot.define do
  factory :user_recap, class: 'User::Recap' do
    user { nil }
    log { "MyText" }
    total_audits { 1 }
    users_modified { 1 }
    notes_made { 1 }
    package_modifications { 1 }
  end
end
