FactoryBot.define do
  factory :invite_rule do
    sport
    state
    invitable { false }
    certifiable { false }
    grad_year { 1 }
  end
end
