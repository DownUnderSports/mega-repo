# encoding: utf-8
# frozen_string_literal: true

module API
  class HomeGalleryController < API::ApplicationController
    class << self
      def images
        get_images unless @image_list.present?
        @image_list.shuffle
      end

      private
        def api_key
          @api_key ||= Rails.application.credentials.dig(:smugmug, :api_key)
        end

        def get_images
          uri = URI('https://api.smugmug.com/api/v2/user/downundersports!popularmedia?MediaType=Images')
          params = { APIKey: api_key }
          uri.query = URI.encode_www_form(params)
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true
          request = Net::HTTP::Get.new(uri.request_uri)
          request['Accept'] = 'application/json'
          puts "\n\nRESPONSE: ", (response = (JSON.parse(http.request(request).body)['Response'] || {})['Image']), "\n\n"
          images = response.map do |i|
            {
              thumbnail: i['ThumbnailUrl'],
              full: i['ThumbnailUrl'].sub('/Th/', '/L/').sub('-Th.', '.'),
              alt: i['ThumbnailUrl'].match(/.*\.com\/(.*?\/.*?)\/.*$/)[1],
            }
          end
          @image_list = images
        end
    end

    def index
      return render json: HomeGalleryController.images
    end
  end
end
