FactoryBot.define do
  factory :source do
    sequence(:name) {|n| "source#{n}"}
  end
end
