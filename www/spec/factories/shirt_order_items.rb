FactoryBot.define do
  factory :shirt_order_item, class: 'ShirtOrder::Item' do
    shirt_order { nil }
    size { "MyText" }
    is_youth { false }
    quantity { 1 }
    price { "" }
    sent { 1 }
    complete { false }
  end
end
