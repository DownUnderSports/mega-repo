Dir["#{Rails.root}/lib/handlers/**/*.rb"].map {|f| require_dependency f }
