FactoryBot.define do
  factory :address do
    sequence(:street) {|n| "Street #{n}" }
    sequence(:city) {|n| "City #{n}" }
    state
    zip { "11111" }
    tz_offset { -6 }
    dst { true }

    factory :pre_verified_address do
      verified { true }
      keep_verified { true }
    end
  end
end
