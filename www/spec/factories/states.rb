FactoryBot.define do
  factory :state do
    sequence(:abbr) {|n| "ABR#{n}"}
    sequence(:full) {|n| "FullName#{n}"}
    conference { "MyText" }
    is_foreign { false }
  end
end
