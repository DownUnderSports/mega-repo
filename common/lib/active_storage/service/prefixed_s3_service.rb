# require "#{Gem::Specification.find_by_name('activestorage').gem_dir}/lib/active_storage/service/s3_service"
require 'aws-sdk-s3'
require 'active_storage/service/s3_service'
require 'active_support/core_ext/numeric/bytes'

module ActiveStorage
  class Service::PrefixedS3Service < Service::S3Service
    attr_reader :client, :bucket, :prefix, :upload_options

    def initialize(bucket:, upload: {}, **options)
      @prefix = options.delete(:prefix)
      super(bucket: bucket, upload: upload, **options)
    end

    private

    def object_for(key)
      path = prefix.present? ? File.join(prefix, key) : key
      bucket.object(path)
    end
  end
end
