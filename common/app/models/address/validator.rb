# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address'

class Address < ApplicationRecord
  class Validator
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.const_missing(name)
      case name
      when :Batch
        require 'smartystreets_ruby_sdk/static_credentials'
        const_set name, SmartyStreets::Batch
      when :ClientBuilder
        require 'smartystreets_ruby_sdk/client_builder'
        const_set name, SmartyStreets::ClientBuilder
      when :Credentials
        require 'smartystreets_ruby_sdk/static_credentials'
        const_set name, SmartyStreets::StaticCredentials.new(
          Rails.application.credentials.smarty_streets[:auth_id],
          Rails.application.credentials.smarty_streets[:auth_token]
        )
      when :StreetLookup
        require 'smartystreets_ruby_sdk/us_street/lookup'
        const_set name, SmartyStreets::USStreet::Lookup
      when :ZipLookup
        require 'smartystreets_ruby_sdk/us_zipcode/lookup'
        const_set name, SmartyStreets::USZipcode::Lookup
      else
        super
      end
    end

    def self.build_address(address)
      lookup = StreetLookup.new
      lookup.street = address.street
      lookup.street2 = address.street_2
      lookup.city = address.city
      lookup.state = address.state.abbr
      lookup.input_id = address.id
      lookup
    end

    def self.validate_address(address)
      validate_addresses([address])
    end

    def self.validate_addresses(addresses)
      return Batch.new if addresses.size == 0
      client = ClientBuilder.new(Credentials).build_us_street_api_client
      batch = Batch.new

      addresses.each do |address|
        begin
          batch.add(build_address(address))
        rescue
          address.update_columns(tz_offset: normalize_tz_offset(address.tz_offset.to_i == 0 ? (address.state&.tz_offset || 0) : address.tz_offset), rejected: true, verified: true)
        end
      end

      begin
        client.send_batch(batch)
      rescue SmartyException => err
        puts err
        return
      end

      batch.each_with_index do |lookup, i|
        candidates = lookup.result
        if address = ::Address.find_or_retry_by(id: lookup.input_id)
          begin
            variant = address.find_variant_by_value

            Current.user = auto_worker

            if candidates.blank?
              address.update_columns(tz_offset: normalize_tz_offset(address.state&.tz_offset || 0), rejected: true, verified: true)
              next
            end

            address_candidates = []

            candidate_exists = ->(cndt) do
              address_candidates.any? do |existing|
                ::Address.normalize(existing) == ::Address.normalize(cndt)
              end
            end

            candidates.each do |candidate|
              addr_candidate = build_candidate(::Address.new, candidate)
              address_candidates << addr_candidate unless candidate_exists.call(addr_candidate)
            end

            if address_candidates.size == 1
              puts "Single candidate".ljust(80, ' ')
              # p address.class
              found_addr = address_candidates.first
              found_addr.student_list_id = address.student_list_id
              found_addr.save

              address.found_verified(found_addr)
              next
            end


            puts "Multi candidate".ljust(80, ' ')
            candidate_ids = []
            address_candidates.each do |a|
              a.student_list_id = address.student_list_id
              a.save
              candidate_ids << a.id
            end
            variant.update(candidate_ids: candidate_ids.sort.uniq)
          rescue
          end
        end
      end
      batch || []
    end

    def self.build_candidate(address, candidate)
      components = candidate.components
      metadata = candidate.metadata
      address.street = candidate.delivery_line_1
      address.street_2 = candidate.delivery_line_2
      address.city = components.city_name
      address.state = State.find_by(abbr: components.state_abbreviation)
      address.zip = "#{components.zipcode}#{valid_plus_4(components.plus4_code)}"
      address.tz_offset = metadata.utc_offset.to_d.hours.to_i
      address.tz_offset = address.state&.tz_offset.to_i if (address.tz_offset == 0)
      address.tz_offset = normalize_tz_offset(address.tz_offset)
      address.dst = Boolean.strict_parse(metadata.obeys_dst)
      address.verified = true
      address
    end

    def self.valid_plus_4(last_four)
      last_four.blank? ? "" : "-#{last_four}"
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

  end
end
