module CommonConfigs
  def self.add_paths(config)
    config.paths.add "vendor/common/app",                 eager_load: true, glob: "{*,*/concerns}"
    config.paths.add "vendor/common/app/assets",          glob: "*"
    config.paths.add "vendor/common/app/controllers",     eager_load: true
    config.paths.add "vendor/common/app/channels",        eager_load: true, glob: "**/*_channel.rb"
    config.paths.add "vendor/common/app/helpers",         eager_load: true
    config.paths.add "vendor/common/app/models",          eager_load: true
    config.paths.add "vendor/common/app/mailers",         eager_load: true
    config.paths.add "vendor/common/app/views"

    config.paths.add "vendor/common/lib",                 load_path: true
    config.paths.add "vendor/common/lib/tasks",           glob: "**/*.rake"

    config.paths.add "vendor/common/config/common_routes", eager_load: true

    config.after_initialize do
      Dir[Rails.root.join("vendor", "common", "config", "initializers", "**/*.rb")].each do |f|
        require f
      end
      Dir[Rails.root.join("vendor", "common", "config", "after_initialize", "**/*.rb")].each do |f|
        require f
      end
    end
  end

  def self.require_environment
    require_dependency Rails.root.join('vendor', 'common', 'config', 'environments', Rails.env)
  end

  def self.common_settings(config, raven_url = nil)
    # Initialize global functions and required modules
    Dir["#{config.root}/vendor/common/lib/groundwork/*"].map {|f| require_dependency f }

    ENV['GNUPGHOME'] = config.root.join('.gnupg').to_s

    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 5.2
    config.active_record.schema_format = :sql
    config.active_record.cache_timestamp_format = :nsec
    config.active_record.dump_schemas = :all

    # Require common app modules
    config.after_initialize do
      Dir["#{config.root}/vendor/common/lib/modules/**/*"].map {|f| require_dependency f }
      Dir["#{config.root}/lib/modules/**/*"].map {|f| require_dependency f }
    end

    # Inject common lookup paths - replaces commented code blow
    add_paths(config)

    # config.eager_load_paths += Dir["#{config.root}/app/models/**/"]
    # config.eager_load_paths += Dir["#{config.root}/app/jobs/**/"]
    # config.eager_load_paths += Dir["#{config.root}/app/policies/**/"]
    # config.eager_load_paths += Dir["#{config.root}/app/mailers/**/"]

    # config.autoload_paths += %W(#{config.root}/config/routes)
    # config.autoload_paths += Dir["#{config.root}/app/models/**/"]
    # config.autoload_paths += Dir["#{config.root}/app/jobs/**/"]
    # config.autoload_paths += Dir["#{config.root}/app/policies/**/"]
    # config.autoload_paths += Dir["#{config.root}/app/mailers/**/"]

    # Configure Time Zone settings
    config.time_zone = 'Mountain Time (US & Canada)'
    config.active_record.default_timezone = :utc

    config.active_job.queue_adapter = :sidekiq
    config.generators do |g|
      g.assets false
    end

    set_routing_seo_info(config)
    set_action_mailer_defaults(config)

    Rails.application.routes.default_url_options[:host] = "lvh.me"

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true
    config.app_generators.scaffold_controller = :scaffold_controller

    set_middlewares(config, raven_url)
    set_session_store(config)
  end

  def self.set_action_mailer_defaults(config)
    config.action_mailer.smtp_settings = {
      :address        => Rails.application.credentials.dig(:mailer, :mailgun, :hostname),
      :port           => Rails.application.credentials.dig(:mailer, :mailgun, :port).to_s,
      :authentication => :plain,
      :user_name      => Rails.application.credentials.dig(:mailer, :mailgun, :username),
      :password       => Rails.application.credentials.dig(:mailer, :mailgun, :password),
      :domain         => 'downundersports.com',
      :enable_starttls_auto => true
    }
    config.action_mailer.delivery_method = :smtp
    config.action_mailer.preview_path = "#{Rails.root}/spec/mailers/previews"
    config.action_mailer.default_url_options = {
      host: config.route_info[:domain]
    }

    config.action_mailer.asset_host = "https://www.downundersports.com"
  end

  def self.set_middlewares(config, raven_url = nil)
    # Middleware for ActiveAdmin
    Dir["#{config.root}/vendor/common/app/middlewares/*"].map {|f| require_dependency f }

    if raven_url
      Raven.configure do |config|
        config.dsn = raven_url
        config.async = lambda { |event|
          SentryJob.perform_later(event)
        }
        config.environments = %w[ production development ]
        config.release = DownUnderSports::VERSION
      end
    end

    config.middleware.use Rack::MethodOverride
    config.middleware.use ActionDispatch::Flash
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use ActionDispatch::Session::CookieStore, **session_store_options
    config.middleware.use QueueTimeLogger
  end

  def self.session_store_options
    sesh_key = (ENV["SESSION_KEY"] || ENV["CURRENT_APP_NAME"] || "_down_under_sports").underscore
    sesh_key = "_#{sesh_key}" unless sesh_key[0] == "_"
    cookie_domain = ".lvh.me"
    {
      key: sesh_key,
      domain: cookie_domain,
      tld_length: 2,
      expire_after: nil,
      secure: false
    }
  end

  def self.set_session_store(config)
    config.session_store :cookie_store, **session_store_options
  end

  def self.set_routing_seo_info(config)
    base_path = Rails.root.join('public')

    unparsed = (File.exist?(base_path.join('routes.json')) ? JSON.parse(File.read(base_path.join('routes.json'))) : {}).to_h.deep_symbolize_keys

    config.route_info = {
      domain: unparsed[:domain].presence || 'http://lvh.me',
      links: unparsed[:links].presence || {},
      current_count: 0
    }

    [
      nil, 'admin'
    ].each do |prefix|
      mfst_path = base_path.join("#{prefix ? "#{prefix}/" : ''}asset-manifest.json")
      mfst_path = File.exist?(mfst_path) && mfst_path
      unparsed = (
        mfst_path ?
        JSON.parse(File.read(mfst_path)) :
        {}
      ).to_h

      unparsed = unparsed['files'].present? ? unparsed['files'] : unparsed

      mfst = :"#{prefix ? "#{prefix}_" : ''}manifest"

      config.route_info[mfst] = (unparsed.presence || {}).
        deep_stringify_keys.
        map {|k,v| [k.sub(/~/, '-'), v.to_s.sub(/~/, '-').sub(/^\//, '')]}.
        to_h

      unparsed = {}

      i = 0

      config.route_info[mfst].each do |k, v|
        tmp_k = k.sub(/static\/.*?\//, '')
        c_buster = tmp_k.match(/^[^.]+(\.[^.]+\.)(chunk\.)?(js|css)$/)

        unparsed[tmp_k] = v
        if c_buster
          subbed = tmp_k.sub(c_buster[1], '.')
          unparsed[subbed] = v
          i = [subbed.to_i, i].max if subbed =~ /^\d+\./
        end

        if k =~ /runtime.*\.js$/
          unparsed[:inline_runtime] = v
        end
      end

      unparsed[:max_count] = (i || 0).to_i + 1

      if mfst_path && config.route_info[mfst]["main.js"]
        html_file_path = Rails.root.join('public', prefix ? 'admin/index.html' : 'client-index.html')
        from_html = (File.exist?(html_file_path) && File.read(html_file_path)).presence
        from_html = from_html&.scan(/(?:src|href)=\"\/?static\/(?:js|css)\/([^."]+\.[^."]+\.chunk\.(?:js|css))\"/)&.flatten.presence || ["main.js"]
        insert_files = from_html.map do |file|
          unparsed[file] || unparsed[file.sub(/(\.[a-z0-9]+)?\.chunk/, '')]
        end.select(&:present?)
      else
        insert_files = []
      end

      unparsed[:insert_js] = insert_files.select {|f| f.to_s =~ /js$/}
      unparsed[:insert_css] = insert_files.select {|f| f.to_s =~ /css$/}

      config.route_info[mfst].merge! unparsed
    end

    config.route_info[:links].each do |route, info|
      info[:image] = unparsed[info[:image]] || info[:image] if info[:image].present?
    end
  end
end
