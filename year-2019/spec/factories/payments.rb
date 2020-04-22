FactoryBot.define do
  factory :payment do
    user { nil }
    shirt_order { nil }
    amount { "" }
    remit_number { "MyText" }
    category { "MyText" }
    billing { "" }
    gateway { "" }
  end
end
