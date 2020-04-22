# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address'

class Address < ApplicationRecord
  # == Constants ============================================================
  ZIP_AREAS =
    begin
      zip_retries = 0
      Rails.env.production? \
       ? JSON.parse(File.read(Rails.root.join('public','json', 'zip-codes.json')))
       : JSON.parse(File.read(Rails.root.join('client', 'src', 'common', 'assets', 'json', 'zip-codes.json')))
    rescue
      if (zip_retries += 1) > 1
        puts $!.message
        puts $!.backtrace
      end
      if Rails.env.development?
        sleep 3
        retry
      else
        {}
      end
    end.to_h.freeze
end
