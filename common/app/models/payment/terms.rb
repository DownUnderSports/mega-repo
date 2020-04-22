# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment'

# Payment::Terms description
class Payment < ApplicationRecord
  class Terms < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :edited_by, class_name: 'User'

    has_many :join_terms, class_name: 'Payment::JoinTerms', foreign_key: :terms_id
    has_many :payments, through: :join_terms

    # == Validations ==========================================================
    validates_presence_of :body, :adult_signed_terms_link, :minor_signed_terms_link

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.latest
      order(:id).last || new
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

  end
end
