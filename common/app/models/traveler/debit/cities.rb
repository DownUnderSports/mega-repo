# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler/debit'

class Traveler < ApplicationRecord
  class Debit < ApplicationRecord
    # == Constants ============================================================
    # CITIES =
    #   begin
    #     Rails.env.production? \
    #      ? JSON.parse(File.read(Rails.root.join('public','json', 'airports.json')))
    #      : JSON.parse(File.read(Rails.root.join('client', 'src', 'common', 'assets', 'json', 'airports.json')))
    #   rescue
    #     {}
    #   end.to_h.
    #   merge(
    #     begin
    #       Rails.env.production? \
    #        ? JSON.parse(File.read(Rails.root.join('public','json', 'airports-extra.json')))
    #        : JSON.parse(File.read(Rails.root.join('client', 'src', 'common', 'assets', 'json', 'airports-extra.json')))
    #     rescue
    #       {}
    #     end.to_h
    #   )
    #   .freeze
  end
end
