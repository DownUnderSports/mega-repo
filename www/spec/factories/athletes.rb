FactoryBot.define do
  factory :athlete do
    school
    source
    grad { 1 }
    respond_date { "2018-07-19" }
    original_school_name { "MyText" }
  end
end
