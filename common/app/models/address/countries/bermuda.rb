# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address/countries'

class Address < ApplicationRecord
  module Countries
    class Bermuda < ::Address
      self.table_name = 'addresses'

      def to_s(formatting = :default)
        case formatting
        when :inline
          "#{street}#{piv(street_2, true)}#{piv(street_3, true)}, #{province} #{zip}, BMU"
        when :streets
          "#{street}, #{piv(street_2, true)}#{piv(street_3, true)}".sub(/,\s+$/, '')
        else
          "#{street}\n#{piv(street_2)}#{piv(street_3)}#{province} #{zip}\nBMU"
        end
      end
    end

    BERMUDA ||= Address::Countries::Bermuda
  end
end
