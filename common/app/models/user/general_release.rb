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

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def serializable_hash(*)
      super.tap do |h|
        t = user&.traveler
        h["payment_data"] = {
                     "dus_id" => user&.dus_id,
                        "age" => user&.age || "Unknown",
                 "birth_date" => user&.birth_date&.inspect,
                "print_names" => user&.print_names,
             "deposit_amount" => t&.deposit_amount,
             "insurance_paid" => t&.insurance_paid_amount,
              "total_charges" => t&.total_charges,
             "total_payments" => t&.total_payments,
          "refundable_amount" => t&.refundable_amount,
             "dreamtime_paid" => t&.dreamtime_paid_amount,
        }.as_json

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
  end
end
