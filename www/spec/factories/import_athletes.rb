FactoryBot.define do
  factory :import_athlete, class: 'Import::Athlete' do
    first { "MyText" }
    last { "MyText" }
    gender { "MyText" }
    grad { 1 }
    stats { "MyText" }
    school_name { "MyText" }
    school_class { "MyText" }
    school
    state
    sport
    source_name { "MyText" }
  end
end
