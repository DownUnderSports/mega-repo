FactoryBot.define do
  factory :address_variant, class: 'Address::Variant' do
    association :address, factory: :pre_verified_address, strategy: :build
    sequence(:value) {|n| "#{n}!@!#{n}!@!#{n}!@!#{n}!@!#{n}!@!#{n}!@!#{n}!@!#{n}" }

    trait :without_value_callback do
      after(:build){|av| av.define_singleton_method(:set_value) { true } }
    end
  end
end
