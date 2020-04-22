FactoryBot.define do
  factory :user_refund_request, class: 'User::RefundRequest' do
    user { nil }
    value { "MyText" }
  end
end
