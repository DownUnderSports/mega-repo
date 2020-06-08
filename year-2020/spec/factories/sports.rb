FactoryBot.define do
  factory :sport do
    abbr { "SP" }
    full { "Sport" }
    sequence(:abbr_gender) {|n| "SP#{n}"}
    sequence(:full_gender) {|n| "Sport#{n}"}
  end
end
