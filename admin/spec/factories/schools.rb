FactoryBot.define do
  factory :school do
    sequence(:pid)
    association :address , factory: :pre_verified_address, street: "School Street #{Time.now.to_i}"
    sequence(:name) {|n| "School Name #{n}" }
    allowed { false }
    allowed_home { false }
    closed { false }
  end
end
