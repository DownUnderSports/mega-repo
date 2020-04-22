# frozen_string_literal: true
require "#{Gem::Specification.find_by_name('activestorage').gem_dir}/app/models/active_storage/blob"

unless ActiveStorage::Blob.method_defined? "read_bytes"
  ActiveStorage::Blob.include ActiveStorageBlobExtensions
end
