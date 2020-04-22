# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class RelationshipType < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :inverse_type,
      inverse_of: :value_type,
      class_name: 'User::RelationshipType',
      foreign_key: :value,
      primary_key: :inverse,
      autosave: false

    has_one :value_type,
      inverse_of: :inverse_type,
      class_name: 'User::RelationshipType',
      foreign_key: :value,
      primary_key: :inverse

    has_many :relations,
      foreign_key: :relationship,
      primary_key: :value

    has_many :inverse_relations,
      class_name: 'User::Relation',
      foreign_key: :relationship,
      primary_key: :inverse

    # == Validations ==========================================================

    # == Scopes ===============================================================
    default_scope { default_order(:value) }

    # == Callbacks ============================================================
    before_validation :set_inverse
    after_commit :create_inverse

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.new(*args)
      super.tap do |r|
        r.value = r.value.to_s.downcase.presence
        r.inverse = r.inverse.to_s.downcase.presence

        r.set_inverse
      end
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def create_inverse
      inverse_type.save
    end

    def set_inverse
      self.inverse_type = self.inverse_type || build_inverse_type(value: inverse, inverse: value, inverse_type: self)
      true
    end

    def build_inverse_type(*args)
      return self if value == inverse
      super
    end

    def save(*args)
      if self.class.find_by(value: value, inverse: inverse)
        true
      else
        super(*args)
      end
    end

    def destroy
      transaction do
        run_callbacks :destroy do
          return if (relations.size > 0) || (inverse_relations.size > 0)
          self.class.where(value: [value, inverse], inverse: [value, inverse]).delete_all
        end
      end
    end
  end
end
