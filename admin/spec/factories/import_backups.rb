FactoryBot.define do
  factory :import_backup, class: 'Import::Backup' do
    upload_type { 'milesplit.com' }
    values do
      hash = {}
      hash
    end
  end
end
