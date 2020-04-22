# encoding: utf-8
# frozen_string_literal: true

require_dependency 'participant/views'

class Participant < ApplicationRecord
  module Views
    class Map < ApplicationRecord
      # == Constants ============================================================

      # == Attributes ===========================================================
      self.table_name = "participants_map_view"

      # == Extensions ===========================================================
      include MaterializedViewExtensions

      # == Relationships ========================================================

      # == Validations ==========================================================

      # == Scopes ===============================================================

      # == Callbacks ============================================================

      # == Boolean Class Methods ================================================

      # == Class Methods ========================================================
      def self.reload_when
        false
      end


      # == Boolean Methods ======================================================

      # == Instance Methods =====================================================

    end
  end
end
