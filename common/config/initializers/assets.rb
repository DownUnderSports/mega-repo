# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path
Dir[Rails.root.join("lib", "assets", "*")].each do |f|
  Rails.application.config.assets.paths << f if File.directory?(f)
end

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += [Rails.root.join("lib", "assets", "config", "manifest.js").to_s]
# Rails.application.config.assets.precompile += Dir[Rails.root.join("lib", "assets", "pdfs", "**", '*.pdf')]
# Rails.application.config.assets.precompile += Dir[Rails.root.join("lib", "assets", "images", "**", '*')]
# Rails.application.config.assets.precompile += Dir[Rails.root.join("lib", "assets", "stylesheets", "*")]
# Rails.application.config.assets.precompile += Dir[Rails.root.join("lib", "assets", "javascripts", "*")]
