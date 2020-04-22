FactoryBot.define do
  factory :import_error, class: 'Import::Error' do
    upload_type { 'milesplit.com' }
    values do
      hash = {}
      hash
    end
  end
end
