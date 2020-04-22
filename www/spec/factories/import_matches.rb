FactoryBot.define do
  factory :import_match, class: 'Import::Match' do
    name { "MyText" }
    school
    state
  end
end
