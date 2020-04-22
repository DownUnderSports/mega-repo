# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class Relation < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, touch: true
    belongs_to :related_user, class_name: 'User'

    belongs_to :inverse_relationship,
      class_name: 'User::Relation',
      foreign_key: :related_user_id,
      primary_key: :user_id,
      optional: true

    belongs_to :relationship_type,
      foreign_key: :relationship,
      primary_key: :value

    # == Validations ==========================================================
    validate :not_related_to_self

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    after_commit :swap_inverse, on: %i[ update ]
    after_commit :create_inverse, on: %i[ create update ]
    after_commit :destroy_inverse, on: %i[ destroy ]

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.new(*args)
      super.tap do |r|
        r.relationship = r.relationship.to_s.downcase.presence
      end
    end

    def self.invalids
      where(user_id: nil).or(where(related_user_id: nil)).or(where(relationship: nil))
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def create_inverse
      (inverse(false) && true) || build_inverse.save
    end

    def destroy_inverse
      (inv = inverse(false)) && inv.destroy
    end

    def inverse(build = true)
      self.class.find_by(user: related_user, related_user: user) || (build && build_inverse)
    end

    def build_inverse
      self.class.new(user: related_user, related_user: user, relationship: relationship_type.inverse)
    end

    def swap_inverse
      self.class.find_by(user: related_user, related_user: previous_changes[:user_id])&.destroy if previous_changes[:user_id]

      if (inv = inverse).relationship != relationship_type.inverse
        inv.update(relationship: relationship_type.inverse)
      end
      true
    end

    private
      def not_related_to_self
        errors.add(:user_id, "can't be related to themself") if (self.user_id == self.related_user_id) && (self.user == self.related_user)
      end

    set_audit_methods!
  end
end
