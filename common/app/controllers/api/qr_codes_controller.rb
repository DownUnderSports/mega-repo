# encoding: utf-8
# frozen_string_literal: true

module API
  class QrCodesController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      s3_asset = s3_bucket.object(url_object_key)
      image_exists = s3_asset.exists?
      generate_and_upload_img unless image_exists

      if image_exists && (gz_file = s3_bucket.object("#{url_object_key}.gz")).exists?
        encodings = {}

        response.headers["Expires"] = 365.days.from_now.httpdate
        response.headers["Cache-Control"] = "private, max-age=#{365.days.to_i}"
        expires_in 365.days, public: false, must_revalidate: true

        if browser.bot?
          encodings[:gz] = true
        else
          request.headers['HTTP_ACCEPT_ENCODING'].to_s.split(',').map {|h| encodings[h.strip.downcase.to_sym] = true }
        end

        # if (encodings[:br] || encodings[:brotli]) && (new_s3 = s3_bucket.object("#{url_object_key}.br")).exists?
        #   response.headers['Content-Encoding'] = 'br'
        #   s3_asset = new_s3
        # els
        if (encodings[:gz] || encodings[:gzip] || encodings[:*])
          response.headers['Content-Encoding'] = 'gz'
          s3_asset = gz_file
        end
      else
        response.headers["Expires"] = 10.minutes.from_now.httpdate
        response.headers["Cache-Control"] = "private, max-age=#{10.minutes.to_i}"
        expires_in 10.minutes, public: false, must_revalidate: true
      end

      response.headers['Content-Type'] = 'image/png; charset=utf-8'

      headers["Content-Disposition"] = "inline; filename=\"#{file_name}\""
      headers["Last-Modified"] = Time.zone.now.ctime.to_s

      return self.response_body = Enumerator.new do |y|
        chunk_size = 512.kilobytes
        offset = 0

        while offset < s3_asset.content_length
          y << s3_asset.get(range: "bytes=#{offset}-#{offset + chunk_size - 1}").body.read
          offset += chunk_size
        end
      end
    end
    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def asking_url
        return @asking_url if @asking_url.present?
        require "base64"
        begin
          @asking_url = Base64.strict_decode64 params[:id]
        rescue
          @asking_url = params[:id]
        end
      end

      def browser
        require 'browser'
        @browser ||= Browser.new(request.headers['HTTP_USER_AGENT'], accept_language: "en-us")
      end

      def clean_user_agent
        @clean_user_agent ||= request.headers['HTTP_USER_AGENT'].to_s.strip.downcase
      end

      def encode_uri_component(string)
        URI.escape(string.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
      end

      def file_name
        "dus-qr-code-#{File.basename(url_object_key)}"
      end

      def generate_and_upload_img
        open_tempfile do |file|
          file.binmode

          QrCodeProcessor.generate(asking_url).write(file)

          file.flush
          file.rewind

          save_to_s3 url_object_key, file
        end
        StoreQrCodeJob.perform_later(asking_url)
      end

      def open_tempfile(ext: '.png', tempdir: nil)
        require 'tempfile'

        file = Tempfile.open([ rand.to_s.sub(/^0\./, ''), ext ], tempdir)

        begin
          yield file
        ensure
          file.close!
        end
      end

      def url_object_key
        @url_object_key ||= "generated_qr_codes/#{encode64(asking_url)}.png"
      end

      def encode64(str)
        require "base64"
        Base64.strict_encode64 str
      end
  end
end
