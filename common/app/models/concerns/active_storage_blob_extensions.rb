# encoding: utf-8
# frozen_string_literal: true

module ActiveStorageBlobExtensions
  extend ActiveSupport::Concern

  ZIP_FILE_SIGNATURE = "PK\x03\x04".freeze

  def read_bytes(*args)
    service.read_bytes(key, *args)
  end

  def is_zip?
    !!(content_type =~ /^application\/zip$/i) &&
    read_bytes(4) == ZIP_FILE_SIGNATURE
  end
end
