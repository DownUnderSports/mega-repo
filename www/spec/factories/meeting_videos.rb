FactoryBot.define do
  factory :meeting_video, class: 'Meeting::Video' do
    category { "" }
    link { "MyText" }
    duration { "" }
    sent { 1 }
    viewed { 1 }
    offer { "" }
  end
end
