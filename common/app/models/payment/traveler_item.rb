# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment/item'

class Payment < ApplicationRecord
  class TravelerItem < Item
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :traveler, optional: false, touch: true
    has_one :user, through: :traveler

    # == Validations ==========================================================

    # == Scopes ===============================================================
    default_scope { where.not(traveler_id: nil) }

    scope :dreamtime, -> do
      joins(:payment).where("#{Payment.arel_table.name}.#{Payment.arel_table["billing"].name}->>'name' ILIKE ?", "Dreamtime%")
    end

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def split!(user_ids, new_times = false)
      user_ids = [ user_ids ] if !user_ids.is_a?(Array)
      users = user_ids.map {|u_id| User.get(u_id)}
      same_last_name = users.all? {|u| user.last == u.last }

      self.description = "Split Payment for #{ same_last_name ? user.first : user.basic_name}"
      users.each do |u|
        last_in_line = u.id == users.last.id
        self.description += "#{last_in_line ? ' and ' : ', '}#{(!last_in_line && same_last_name) ? u.first : u.basic_name}"
      end
      self.name = "Split Account Payment"
      self.price = self.amount /= user_ids.size + 1

      save!

      users.each do |u|
        i = dup
        i.created_at = self.created_at unless new_times
        i.traveler = u.get_or_create_traveler
        i.save!
      end
      self
    end

  end
end
