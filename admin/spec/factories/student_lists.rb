FactoryBot.define do
  factory :student_list do
    sequence(:sent) {|n| (Date.today + n.days).to_date }
  end
end
