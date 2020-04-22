FactoryBot.define do
  factory :invite_stat, class: 'Invite::Stats' do
    submitted { "2018-09-05" }
    mailed { "2018-09-05" }
    estimated { 1 }
    actual { 1 }
  end
end
