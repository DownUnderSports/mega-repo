module Common
  class ApplicationController < ActionController::Base
    prepend_view_path Rails.root.join('vendor', 'common', 'app', 'views')

    def self.not_authorized_error
      Pundit::NotAuthorizedError
    end

    class StreamJSONDeflator
      def self.nil_to_s(v)
        v.nil? ? '' : v
      end

      def initialize(enum, is_array = false)
        @concat = is_array === 'concat'
        @is_array = !@concat && Boolean.parse(is_array)
        @enum = enum
        @deflator = Zlib::Deflate.new
        @depth = 1
        y << @deflator.deflate(@is_array ? '[' : '{') unless @concat
      end

      def y
        @enum
      end

      def stream(comma, k, v, exact = false)
        @depth -= 1 if v.to_s =~ /^\s*[\}\]]/
        y << @deflator.deflate("#{comma ? ',' : ''}\n#{'  ' * @depth}#{k ? "\"#{k}\":" : ''}#{exact ? v : get_json(v)}", Zlib::SYNC_FLUSH)
        @depth += 1 if v.to_s =~ /[\{\[]\s*$/
      end

      def close
        y << @deflator.deflate(@concat ? "\n" : "\n#{@is_array ? ']' : '}'}", Zlib::FINISH)
      end

      def get_json(v)
        if v =~ /!!-->>/
          @setting_options = true
        end
        if @setting_options
          if v =~ /<<--!!/
            @setting_options = false
            v = v.split('<<--!!')
            return "#{v[0]}<<--!!#{get_json(v[1])}"
          end

          return v
        end
        return v if (v =~ /[{}\[\]]|--JSON--([A-Z]+--)*|!!-->>|<<--!!/)
        (v.is_a?(Hash) || v.is_a?(Array) || v.is_a?(ActiveRecord::Base)) ? JSON.pretty_generate(v.as_json, depth: @depth) : nil_to_s(v).to_json
      end

      def nil_to_s(v)
        self.class.nil_to_s(v)
      end
    end

    class StreamCSVDeflator
      def initialize(enum)
        @enum = enum
        @deflator = Zlib::Deflate.new
      end

      def y
        @enum
      end

      def stream(row)
        y << @deflator.deflate(CSV.generate_line(row, force_quotes: true, encoding: 'utf-8'), Zlib::SYNC_FLUSH)
      end

      def close
        y << @deflator.flush(Zlib::FINISH)
      end
    end

    protect_from_forgery with: :exception
    include BetterRecord::Authenticatable
    include Fetchable
    helper ViewAndControllerMethods
    include ViewAndControllerMethods
    before_action :set_language
    before_action :filter_http_verbs
    before_action :set_values
    after_action :collect_garbage, if: -> { request.format.csv? || ((route_info[:current_count] += 1) % 20 == 0) }

    def clear_logs
      20_000.times { puts ' ' }
      return redirect_to "/", status: 303
    end

    def request_origin
      @request_origin ||= get_request_origin
      @request_origin.to_s
    end

    def get_request_origin
      %w[
        origin
        http_origin
        raw_origin
      ].each do |k|
        v = request.env[k]
        %i[
          upcase
          downcase
          titleize
        ].each do |m|
          return v if (v = request.env[k.__send__(m)]).present?
          return v if (v = header_hash[k.__send__(m).to_sym]).present?
        end
      end

      nil
    rescue
      nil
    end

    def cookie_domain
      Rails.env.production? ? '.downundersports.com' : :all
    end

    def set_current_user_cookies(user_to_set = nil)
      if user_to_set ||= BetterRecord::Current.user
        result = (
          cookies.encrypted[:current_user_id] = {
            value: user_to_set.id,
            expires: Time.now + 24.hours,
            secure: Rails.env.production?,
            domain: cookie_domain,
            tld_length: 2
          }.merge!(Rails.env.production? ? { same_site: :lax } : {})
        )

        cookies[:plain_id] = {
          value: user_to_set.id,
          expires: Time.now + 24.hours,
          secure: Rails.env.production?,
          domain: cookie_domain,
          tld_length: 2
        }.merge!(Rails.env.production? ? { same_site: :none } : {})

        if Rails.env.production?
          cookies.encrypted[:current_user_id_legacy] = {
            value: user_to_set.id,
            expires: Time.now + 24.hours,
            secure: Rails.env.production?,
            domain: cookie_domain,
            tld_length: 2
          }

          cookies[:plain_id_legacy] = {
            value: user_to_set.id,
            expires: Time.now + 24.hours,
            secure: Rails.env.production?,
            domain: cookie_domain,
            tld_length: 2
          }
        end

        result
      else
        cookies.delete :current_user_id, domain: cookie_domain, tld_length: 2
        cookies.delete :current_user_id_legacy, domain: cookie_domain, tld_length: 2
        cookies.delete :plain_id, domain: cookie_domain, tld_length: 2
        cookies.delete :plain_id_legacy, domain: cookie_domain, tld_length: 2
        nil
      end
    end

    def no_op
      set_current_user_cookies

      return head current_user ? 200 : 500
    rescue
      return head
    end

    def version
      render plain: DownUnderSports::VERSION
    end

    def user_not_authorized
      raise not_authorized_error
    end

    def oembed
      path = params[:url].split(/.*?\/\/.*\//)[1]
      path_data(path)
      respond_to do |format|
        format.json do
        end
        format.xml do
        end
      end
    end

    def fallback_index_html
      @disallow_ssr_render_caching ||= true || Boolean.parse(params[:rendering_no_cache]) || request.original_url =~ /^(admin|authenticate|authorize)/

      response.headers["Cache-Control"] = "max-age=0, must-revalidate"

      if timestamp = can_cache_html?
        if stale?(html_cache_options(timestamp))
          raise "Invalid" unless (cached = get_html_cache_body).present?
          return render html: cached.html_safe, layout: false
        end
      else
        CacheRouteJob.perform_later(request.original_url) unless @disallow_ssr_render_caching
        return render html: '', layout: true
      end
    rescue
      puts $!.message, $!.backtrace
      return render html: '', layout: true
    end

    def can_cache_html?
      !@disallow_ssr_render_caching && get_html_timestamp
    end

    def get_html_timestamp
      Rails.redis.get(url_cache_timestamp_key(request.original_url))
    end

    def get_html_cache_body
      Rails.redis.get(url_cache_base_key(request.original_url))
    end

    def html_cache_options(timestamp)
      {
        etag: [ DownUnderSports::VERSION, request.original_url ],
        last_modified: Time.zone.parse(timestamp || Time.now.to_s),
        template: false
      }
    end

    def identifier
      return render json: { identifier: requesting_device_id }
    end

    def app_base
      'client'
    end

    def app_build_path
      Rails.root.join(app_base, 'build')
    end

    def s3_asset_path
      ENV.fetch("S3_ASSET_PREFIX") { 'assets' }
    end

    def html_path
      Rails.root.join(app_build_path, 'index.html')
    end
    helper_method :html_path

    def random_background
      response.headers["Cache-Control"] = "max-age=0, must-revalidate"

      dir = Dir.glob("#{Rails.root.join("public", "images")}/*-background.jpg") rescue []
      file = dir.sample.to_s.sub(Rails.root.join("public").to_s, "")

      redirect_to file.presence || "/dus-logo.png", status: 307
    end

    def serve_asset
      response.headers['Vary'] = 'User-Agent'

      cleaned = "#{request.path}".gsub('!', '.')

      until cleaned !~ /^\/+|^(public|assets|admin|travel|aus)?\/|\.+\//
        puts "UNCLEANED: #{cleaned}"
        cleaned = cleaned.
          sub(/^\/*(public|assets|admin|travel|aus)\/+|^\/+/, '').
          gsub(/\.+\/.*|[\?\*].*/, '')
      end
      puts "CLEANED: #{cleaned}"

      file = Rails.root.join(app_build_path, cleaned).to_s
      s3_asset = false

      if !File.exist?(file)
        if match = match_javascript_file(cleaned)
          file = Rails.root.join(match[0], match[1]).to_s
        elsif(Rails.application.assets_manifest.files[cleaned])
          file = "#{Rails.application.assets_manifest.dir}/#{cleaned}"
        elsif (s3_asset = S3AssetManager.object_if_exists(cleaned, s3_asset_path))
          file = cleaned
        else

          sub_cleaned = cleaned.sub(/-[A-Za-z0-9]{64}/, '')
          loop do
            found_asset =
              Rails.
                application.
                assets_manifest.
                files.
                values.
                select {|v| v['logical_path'] === sub_cleaned.to_s}.
                first

            if found_asset
              v = found_asset['logical_path'].split('.')

              file = "#{Rails.application.assets_manifest.dir}/#{v[0...-1].join('.')}-#{found_asset['digest']}.#{v[-1]}"
            end

            break if File.exist?(file) || (sub_cleaned !~ /\//)

            sub_cleaned = sub_cleaned.split("/")[1..-1].join("/")
          end
        end
      end

      unless s3_asset || File.exist?(file)
        file = Rails.root.join('public', 'assets', cleaned).to_s
        file = Rails.root.join('public', cleaned).to_s unless File.exist?(file)
      end

      if s3_asset
        encodings = {}
        request.headers.each do |h, k|
          if h.to_s =~ /(user|agent)/i
            p "#{h}: #{k}", !!bot_request
          end
        end

        if (cleaned =~ /.*\.[A-Za-z0-9]+\.[a-z]+$/) || (params.to_unsafe_h.keys.any? {|k| k.to_s =~ /^[0-9]+$/})
          response.headers["Expires"] = 365.days.from_now.httpdate
          response.headers["Cache-Control"] = "private, max-age=#{365.days.to_i}"
          expires_in 365.days, public: false, must_revalidate: true
        end

        if browser.bot?
          encodings[:gz] = true
        else
          request.headers['HTTP_ACCEPT_ENCODING'].to_s.split(',').map {|h| encodings[h.strip.downcase.to_sym] = true }
        end

        if (encodings[:br] || encodings[:brotli]) && (new_s3_asset = S3AssetManager.object_if_exists("#{cleaned}.br", s3_asset_path))
          response.headers['Content-Encoding'] = 'br'
          s3_asset = new_s3_asset
        elsif (encodings[:gz] || encodings[:gzip] || encodings[:*]) && (new_s3_asset = S3AssetManager.object_if_exists("#{cleaned}.gz", s3_asset_path))
          response.headers['Content-Encoding'] = 'gz'
          s3_asset = new_s3_asset
        end

        response.headers['Content-Type'] =
          mime_types[file.split('.').last.downcase.strip.to_sym] || 'application/javascript; charset=utf-8'

        iphone_pdf = !!(file =~ /\.pdf/) && browser.platform.ios?

        headers["Content-Disposition"] = "#{(iphone_pdf ? 'attachment' : 'inline')}; filename=\"#{File.basename(file)}\""
        headers["Last-Modified"] = Time.zone.now.ctime.to_s

        return self.response_body = Enumerator.new do |y|
          chunk_size = 512.kilobytes
          offset = 0

          while offset < s3_asset.content_length
            y << s3_asset.get(range: "bytes=#{offset}-#{offset + chunk_size - 1}").body.read
            offset += chunk_size
          end
        end
      elsif File.exist?(file)
        encodings = {}
        request.headers.each do |h, k|
          if h.to_s =~ /(user|agent)/i
            p "#{h}: #{k}", !!bot_request
          end
        end

        if (cleaned =~ /.*\.[A-Za-z0-9]+\.[a-z]+$/) || (params.to_unsafe_h.keys.any? {|k| k.to_s =~ /^[0-9]+$/})
          response.headers["Expires"] = 365.days.from_now.httpdate
          response.headers["Cache-Control"] = "private, max-age=#{365.days.to_i}"
          expires_in 365.days, public: false, must_revalidate: true
        end

        if browser.bot?
          encodings[:gz] = true
        else
          request.headers['HTTP_ACCEPT_ENCODING'].to_s.split(',').map {|h| encodings[h.strip.downcase.to_sym] = true }
        end

        response.headers['Content-Type'] =
          mime_types[file.split('.').last.downcase.strip.to_sym] ||
          `file --b --mime-type '#{file}'`.strip

        iphone_pdf = !!(file =~ /\.pdf/) && browser.platform.ios?

        return send_file file, {
          type: response.headers['Content-Type'],
          disposition: (iphone_pdf ? 'attachment' : 'inline')
        }.merge(browser.safari? ? { filename: get_file_name(file) } : {})
      elsif request.path.to_s =~ /static/
        redirect_to 'https://www.downundersports.com', status: 404
      elsif request.format.to_s == '*/*'
        return fallback_index_html
      end
    end

    rescue_from ActiveRecord::RecordNotFound, :with => :rescue_action_in_public
    rescue_from Net::ProtocolError, :with => :redirect_to_https

    private
      def browser
        require 'browser'
        @browser ||= Browser.new(request.headers['HTTP_USER_AGENT'], accept_language: "en-us")
      end

      def bot_request
        browser.bot? || !!(clean_user_agent =~ /^face(bot|book)/)
      end

      def clean_user_agent
        @clean_user_agent ||= request.headers['HTTP_USER_AGENT'].to_s.strip.downcase
      end

      def collect_garbage
        GC.start
      end

      def csv_headers(file_name, deflate: true, encoding: 'utf-8', modified: Time.zone.now.ctime.to_s, disposition: 'attachment', timestamp: Time.zone.now.to_s)
        download_headers(
          file_name: file_name,
          deflate: deflate,
          encoding: encoding || 'utf-8',
          modified: modified,
          content_type: 'text/csv',
          disposition: disposition,
          timestamp: timestamp,
          extension: 'csv'
        )
      end

      def json_headers(deflate: true, encoding: 'utf-8', modified: Time.zone.now.ctime.to_s, content_type: 'application/json', disposition: 'inline', extension: 'json', file_name: nil, timestamp: nil)
        download_headers(
          file_name: file_name,
          deflate: deflate,
          encoding: encoding || 'utf-8',
          modified: modified,
          content_type: content_type,
          disposition: disposition,
          timestamp: timestamp,
          extension: extension
        )
      end

      def download_headers(deflate:, content_type:, encoding:, modified:, disposition:, extension: 'csv', file_name: nil, timestamp: Time.zone.now.to_s)
        expires_now
        headers["X-Accel-Buffering"] = 'no'
        headers["Content-Type"] = "#{content_type}; charset=#{encoding}"
        headers["Content-Disposition"] = file_name ? %(#{disposition}; filename="#{file_name}#{timestamp ? "-#{timestamp}" : ''}.#{extension}") : disposition
        headers["Content-Encoding"] = 'deflate' if deflate
        headers["Last-Modified"] = modified
      end

      def decrypt_token(token, options = nil, **other)
        value, gpg_status = token.presence && decrypt_gpg_base64(token).presence
        puts gpg_status if Rails.env.development?
        value
      rescue Exception
      end

      def encrypt_token
        current_token.presence && encrypt_and_encode_str(current_token)
      rescue Exception
        puts $!.message
        puts $!.backtrace
        nil
      end

      def get_file_name(file)
        file.to_s.split('/').last.sub(/\.(gz|br)[^.]*?/, '')
      end

      def not_authorized_error
        self.class.not_authorized_error
      end

      def not_authorized(errors = nil, status = 401)
        errors = case errors
        when not_authorized_error, nil
          [ 'You are not authorized to perform the requested action' ]
        when String
          [
            errors
          ]
        else
          errors
        end

        return render json: {
          errors: errors
        }, status: 403
      end

      # handles 404 when an asset is not found.
      def rescue_action_in_public(exception)
        case exception
        when ActiveRecord::RecordNotFound, ActionController::UnknownAction, ActionController::RoutingError
          render render html: '', layout: true, :status => 404
        else
          super
        end
      end

      def redirect_to_https
        redirect_to :protocol => "https://"
      end

      def set_values
        requesting_device_id
      end

      # def get_ip_address
      #   header_hash[:HTTP_X_REAL_IP] ||
      #   header_hash[:HTTP_CLIENT_IP] ||
      #   request.remote_ip
      # end

      def filter_http_verbs
        protocol_check

        unless %w[ GET POST PATCH PUT DELETE OPTIONS HEAD ].include?(request.method)
          raise ActionController::MethodNotAllowed.new("#{request.method} http request method not allowed")
        end

      end

      def protocol_check
        unless (request.ssl? || request.local?)
          raise Net::ProtocolError
        end
      end

      if Rails.env.development?
        def requesting_device_id
          @requesting_device_id ||= "development"
        end
      end

      def set_language
        response.headers["Content-Language"] = "en-US, en"
      end

      def local_port
        request.port || ENV['LOCAL_PORT'] || '3100'
      end

      def local_domain
        Rails.env.development? ? "lvh.me:#{local_port}" : "downundersports.com"
      end

      def match_javascript_file(file)
        filename = File.basename(file)
        path_from_js_manifest(js_files_manifest, filename)
      end

      def js_files_manifest
        return @js_files_manifest if @js_files_manifest.present?

        @js_files_manifest ||=
          (
            File.exist?(app_build_path.join('files-list.json')) ?
            JSON.parse(File.read(app_build_path.join('files-list.json'))) :
            {}
          ).to_h
      end

      def path_from_js_manifest(hash, key, path = nil)
        path = path || app_build_path
        if hash[key]
          return [ path, key, hash[key] ]
        else
          hash.each do |sub_key, v|
            if v.is_a?(Hash)
              found = path_from_js_manifest(v, key, Rails.root.join(path, sub_key))
              return found if found
            end
          end
        end

        false
      end
  end
end
