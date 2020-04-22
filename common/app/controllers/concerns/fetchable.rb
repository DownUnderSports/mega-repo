# encoding: utf-8
# frozen_string_literal: true

module Fetchable
  extend ActiveSupport::Concern

  # == Modules ============================================================

  # == Class Methods ======================================================

  # == Pre/Post Flight Checks =============================================

  # == Actions ============================================================

  # == Cleanup ============================================================

  # == Utilities ==========================================================

  private
    def fetch(uri_str, limit = 10)
      require 'net/http'

      raise ArgumentError, 'too many HTTP redirects' if limit == 0

      resulting = Net::HTTP.get_response(URI(uri_str))

      case resulting
      when Net::HTTPSuccess then
        resulting.body
      when Net::HTTPRedirection then
        loc = resulting['location']
        warn "redirected to #{loc}"
        fetch(loc, limit - 1)
      else
        begin
          resulting.value
        rescue
          begin
            resulting.body
          rescue
            resulting
          end
        end
      end
    end
end
