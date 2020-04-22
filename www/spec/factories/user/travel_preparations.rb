FactoryBot.define do
  factory :user_travel_preparation, class: 'User::TravelPreparation' do
    applied_for_passport_date { "2019-09-18" }
    applied_for_eta_date { "2019-09-18" }
    domestic_followup_date { "2019-09-18" }
    insurance_followup_date { "2019-09-18" }
    has_multiple_citizenships { false }
    citizenships_array { [] }
    has_aliases { false }
    aliases_array { [] }
    has_convictions { false }
    convictions_array { [] }
    eta_email_date { "2019-09-18" }
    visa_message_sent_date { "2019-09-18" }
    extra_eta_processing { false }
  end
end
