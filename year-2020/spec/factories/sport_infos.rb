FactoryBot.define do
  factory :sport_info, class: 'Sport::Info' do
    sport
    title { "MyText" }
    tournament { "MyText" }
    first_year { 1 }
    departing_dates { "MyText" }
    team_count { "MyText" }
    team_size { "MyText" }
    description { "MyText" }
    bullet_points_array { [] }
    additional { "MyText" }
  end
end
