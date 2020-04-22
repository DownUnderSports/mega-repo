FactoryBot.define do
  factory :meeting_registration, class: 'Meeting::Registration' do
    meeting { nil }
    user { nil }
    athlete { nil }
    attended { false }
    duration { "" }
    questions { "MyText" }
  end
end
