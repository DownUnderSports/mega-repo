ActiveRecord::Base.transaction do
  Dir.glob("#{File.expand_path(__dir__)}/seeds/shared/*.rb").sort.each do |shared_seed_file|
    puts "- - Seeding shared data from file: #{shared_seed_file}"
    require shared_seed_file
  end

  seed_file = "#{Rails.root}/db/seeds/#{Rails.env}.rb"
  if File.exist?(seed_file)
    puts "- - Seeding data from file: #{Rails.env}"
    require seed_file
  end
end
