FactoryBot.define do
  factory :meeting do
    category { "" }
    host { nil }
    tech { nil }
    start_time { "2018-09-17 14:02:15" }
    duration { "" }
    registered { 1 }
    attended { 1 }
    represented_registered { 1 }
    represented_attended { 1 }
    join_link { "MyText" }
    recording_link { "MyText" }
    notes { "MyText" }
    questions { "MyText" }
  end
end
