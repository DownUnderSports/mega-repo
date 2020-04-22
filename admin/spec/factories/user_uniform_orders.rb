FactoryBot.define do
  factory :user_uniform_order, class: 'User::UniformOrder' do
    user { nil }
    submitter { nil }
    sport { nil }
    jersey_size { "MyText" }
    shorts_size { "MyText" }
    jersey_number { 1 }
    preferred_number_1 { 1 }
    preferred_number_2 { 1 }
    preferred_number_3 { 1 }
    cost { "" }
    submitted_to_shop_at { "2019-03-22 11:21:29" }
    invoice_date { "2019-03-22" }
    shipped_date { "2019-03-22" }
    shipping { "" }
  end
end
