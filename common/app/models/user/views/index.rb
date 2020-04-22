# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/views'

class User < ApplicationRecord
  module Views
    class Index < User
      # == Constants ============================================================

      # == Attributes ===========================================================
      self.table_name = "users_index_view"

      # == Extensions ===========================================================
      include MaterializedViewExtensions

      # == Relationships ========================================================

      # == Validations ==========================================================

      # == Scopes ===============================================================
      scope :athletes_this_year, -> do
        athletes.
        visible.
        where(arel_table[:grad].gteq(current_year.to_i)).
        or(visible_reason)
      end

      scope :visible_reason, -> do
        athletes.
        visible.
        where(grad: nil).
        or(where_not_exists(:related_users, category_type: BetterRecord::PolymorphicOverride.all_types(Athlete)))
      end

      # == Callbacks ============================================================

      # == Boolean Class Methods ================================================

      # == Class Methods ========================================================
      def self.default_print
        %i[
          id
          dus_id
          category
          gender
          full_name
          print_names
          email
          phone
          address_id
        ]
      end

      def self.reload_when
        !batch_updates &&
          !(last_refresh &.< User.try(:maximum, :created_at))
          !(last_refresh &.> 5.minutes.ago)
      end

      # == Boolean Methods ======================================================

      # == Instance Methods =====================================================
      def parent_class
        User
      end

    end
  end
end
