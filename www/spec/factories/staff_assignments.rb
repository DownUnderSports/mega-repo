FactoryBot.define do
  factory :staff_assignment, class: 'Staff::Assignment' do
    assigned_to { nil }
    assigned_by { nil }
    user { nil }
    completed { false }
    unneeded { false }
    reviewed { false }
    completed_at { "2019-01-30 10:53:12" }
    unneeded_at { "2019-01-30 10:53:12" }
    reviewed_at { "2019-01-30 10:53:12" }
  end
end
