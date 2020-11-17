# encoding: utf-8
# frozen_string_literal: true

class User < ApplicationRecord
  class GeneralRelease < ApplicationRecord
    # == Constants ============================================================
    TOTAL_PAID = 90556699

    # == Attributes ===========================================================
    has_one_attached :release_form

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_validation :set_percentage
    before_save :set_percentage
    after_commit :set_cache

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================
    def cache_needs_update?
      t = user&.traveler
      last_update = [ t&.updated_at, user&.updated_at, t&.items&.try(:maximum, :updated_at) ].select(&:present?).max
      !!last_update && (updated_at <= last_update)
    end

    # == Instance Methods =====================================================
    def serializable_hash(*)
      super.tap do |h|
        h["release_form"] = release_form.attached? ? Rails.application.routes.url_helpers.rails_blob_path(release_form, disposition: "inline") : ""

        h
      end
    end

    def set_percentage
      basis = net_refundable.nil? ? (user&.traveler&.refundable_amount || 0.cents) : net_refundable
      self.percentage_paid = basis.to_i.to_d / TOTAL_PAID.to_d
    end

    def net_refundable
      self[:net_refundable].blank? ? nil : StoreAsInt.money(self[:net_refundable])
    end

    def net_refundable=(value)
      if value.blank?
        super(nil)
      else
        super(StoreAsInt.money(value).to_i)
      end
    end

    def set_cache
      update_or_create_cache if cache_needs_update?
      true
    end

    def generate_additional_data
      t = user&.traveler

      self.additional_data = {
                   "dus_id" => user&.dus_id,
                      "age" => user&.age || "Unknown",
               "birth_date" => user&.birth_date&.inspect,
              "print_names" => user&.print_names,
           "deposit_amount" => t&.deposit_amount.as_json,
           "insurance_paid" => t&.insurance_paid_amount.as_json,
            "total_charges" => t&.total_charges.as_json,
           "total_payments" => t&.total_payments.as_json,
        "refundable_amount" => t&.refundable_amount.as_json,
           "dreamtime_paid" => t&.dreamtime_paid_amount.as_json,
      }

      self
    end

    def update_or_create_cache
      generate_additional_data
      save
    end

    def update_or_create_cache!
      generate_additional_data
      save!
    end
  end
end
