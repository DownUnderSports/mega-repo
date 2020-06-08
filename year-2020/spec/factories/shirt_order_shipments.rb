FactoryBot.define do
  factory :shirt_order_shipment, class: 'ShirtOrder::Shipment' do
    shirt_order { nil }
    shirts { "" }
    shirts_count { 1 }
    sent { "2018-09-14" }
    shipped_to { "" }
    failed { false }
  end
end
