FactoryBot.define do
  factory :meeting_video_view, class: 'Meeting::Video::View' do
    video { nil }
    user { nil }
    athlete { nil }
    watched { false }
    duration { false }
    questions { "MyText" }
  end
end
