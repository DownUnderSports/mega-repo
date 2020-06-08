FactoryBot.define do
  factory :shirt_order do
    total_price { "" }
    shirts_ordered { 1 }
    shirts_sent { 1 }
    shipping { "" }
    complete { false }
  end
end
