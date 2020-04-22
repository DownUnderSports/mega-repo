# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler/base_debit'

class Traveler < ApplicationRecord
  class Debit < ApplicationRecord
    # == Constants ============================================================

    # AIRFARE
    # CITIES

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.traveler_debits"

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :base_debit, inverse_of: :debits
    belongs_to :traveler, inverse_of: :debits, touch: true
    belongs_to :assigner, class_name: 'User', optional: true

    delegate_blank :name, :description, to: :base_debit

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    after_commit :remove_redundant, on: %i[ create update ]
    after_commit :set_insurance
    after_commit :set_traveler_details

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.airfare(assigner, traveler, dep, ret = nil, amount_override = nil)
      debit = nil

      transaction do
        Traveler::Debit.
          where(
            base_debit: [
              Traveler::BaseDebit::Domestic,
              Traveler::BaseDebit::OwnDomestic
            ],
            traveler: traveler
          ).destroy_all

        base = Traveler::BaseDebit::Domestic
        ret = (ret || dep).to_s.upcase
        dep = dep.to_s.upcase

        begin
          # raise "Airport \"#{dep}\" NOT FOUND" unless dep_city = (CITIES[dep] || Flight::Airport[dep]&.to_desc)
          # raise "Airport \"#{ret}\" NOT FOUND" unless ret_city = (CITIES[ret] || Flight::Airport[ret]&.to_desc)
          raise "Airport \"#{dep}\" NOT FOUND" unless dep_city = Flight::Airport[dep]&.to_desc
          raise "Airport \"#{ret}\" NOT FOUND" unless ret_city = Flight::Airport[ret]&.to_desc
          desc = base.description.sub('%DEP%', (dep == ret) ? '' : dep_city[0] ).sub('%RET%', ret_city[0]).gsub('  ', ' ')
        rescue
          raise "Airport \"#{Flight::Airport[dep]&.to_desc ? ret : dep}\" NOT FOUND"
        end

        debit = new(assigner: assigner, traveler: traveler, base_debit: base, name: "#{base.name}: #{dep}-#{ret}", description: desc, amount: StoreAsInt.money(0))

        [
          dep,
          ret
        ].each do |loc|
          price = Flight::Airport[loc].cost

          raise "Airport \"#{loc}\" PRICE NOT SET" unless price.present? || (AIRFARE[loc] == 0)

          debit.amount += (StoreAsInt.money(price)/2)
        end

        debit.amount = StoreAsInt.money(amount_override) if amount_override.present?

        debit.save!
      end

      debit
    end

    def self.insurance(assigner, traveler)
      debit, price, price_range, desc = nil

      transaction do

        base = Traveler::BaseDebit::Insurance

        begin
          price = traveler.insurance_price
          raise "PRICE NOT FOUND" unless price_range = insurance_price_to_range(price)
          desc =
            base.description +
            "Package Price #{price_range.first.cents.to_s(true)} - #{price_range.last.cents.to_s(true)}".gsub(/\.(00|99)/, '') +
            "\nNon-Refundable"
        rescue
          raise "Insurance Price Not Found"
        end

        debit = traveler.insurance_debit || new

        return debit if debit.persisted? && (debit.amount == price)

        debit.assigner = assigner
        debit.traveler = traveler
        debit.base_debit = base
        debit.description = desc
        debit.amount = price

        debit.save!
      end

      debit
    end

    def self.insurance_price_to_range(int)
      INSURANCE_PRICES.key(int.to_i)
    end

    # == Boolean Methods ======================================================
    def is_airfare?(bd_id = nil)
      (bd_id || base_debit_id).in? [
        Traveler::BaseDebit::Domestic.id,
        Traveler::BaseDebit::OwnDomestic.id,
      ]
    end

    def is_domestic?(bd_id = nil)
      (bd_id || base_debit_id).to_i == Traveler::BaseDebit::Domestic.id
    end

    def is_own_domestic?(bd_id = nil)
      (bd_id || base_debit_id).to_i == Traveler::BaseDebit::OwnDomestic.id
    end

    def is_insurance?(bd_id = nil)
      (bd_id || base_debit_id).to_i == Traveler::BaseDebit::Insurance.id
    end

    # == Instance Methods =====================================================
    private
      def airport_details_changed?
        return true if is_airfare?

        !!(
          previous_changes[:base_debit_id] \
          && !!is_airfare?( Traveler::BaseDebit.find_by(id: previous_changes[:base_debit_id].first)&.name )
        )
      end

      def balance_details_changed?
        !!previous_changes[:amount]
      end

      def set_traveler_details
        traveler&.set_details(
          should_set_airports: airport_details_changed?,
          should_set_balance: balance_details_changed?,
          should_save_details: true,
        )
      end

      def set_insurance
        traveler.set_insurance_price unless is_insurance?
      end

      def remove_redundant
        if is_airfare?
          Traveler::Debit.
            where(
              base_debit: Traveler::BaseDebit.
                const_get(is_domestic? ? :OwnDomestic : :Domestic),
              traveler: traveler
            ).
            destroy_all
        end
      end

    set_audit_methods!
  end
end
