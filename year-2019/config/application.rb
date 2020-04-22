require_relative 'boot'
require_relative 'version'

require 'rails'
# Pick the frameworks you want:
require 'active_model/railtie'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'action_mailer/railtie'
require 'active_job/railtie'
require 'action_cable/engine'
require 'active_storage'
require 'active_storage/engine'
require 'sprockets/railtie'
require 'rails/test_unit/railtie'
require 'csv'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DownUnderSports
  class Application < Rails::Application
    require_dependency Rails.root.join('vendor','common','config','common_configs')

    CommonConfigs.common_settings(config, 'https://7a761b115bfd48c29e7e93b522755699@sentry.io/1774921')
  end
end
