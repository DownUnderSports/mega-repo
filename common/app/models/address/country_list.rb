# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address'

class Address < ApplicationRecord
  # == Constants ============================================================
  COUNTRY_LIST = (
    File.exist?(Rails.root.join('public','json', 'countries.json')) ?
      JSON.parse(File.read(Rails.root.join('public','json', 'countries.json'))) :
      {}
  ).to_h
end
