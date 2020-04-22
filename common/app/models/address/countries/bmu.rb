# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address/countries/bermuda'

class Address < ApplicationRecord
  module Countries
    BMU ||= Address::Countries::BERMUDA
  end
end
