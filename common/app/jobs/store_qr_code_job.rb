# encoding: utf-8
# frozen_string_literal: true

class StoreQrCodeJob < ApplicationJob
  def perform(url)
    @url = url
    generate_and_upload_img
  end

  private
    def url
      @url
    end

    def encode_uri_component(string)
      URI.escape(string.to_s, Regexp.new("[^#{URI::PATTERN::UNRESERVED}]"))
    end

    def file_name
      File.basename(url_object_key)
    end

    def generate_and_upload_img
      open_tempfile do |file|
        file.binmode

        QrCodeProcessor.generate(url).write(file)

        file.flush
        file.rewind

        save_to_s3 url_object_key, file

        file.flush
        file.rewind

        open_tempfile(ext: '.gz') do |gzfile|
          gzfile.binmode

          Zlib::GzipWriter.open(gzfile, Zlib::BEST_COMPRESSION) do |gz|
            gz.mtime = Time.zone.now
            gz.orig_name = file_name
            while chunk = file.read(16*1024) do
              gz.write(chunk)
            end
          end

          gzfile.flush
          gzfile.rewind

          save_to_s3 "#{url_object_key}.gz", file
        end
      end
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
      @url_object_key ||= "generated_qr_codes/#{encode_uri_component(url)}.png"
    end
end
