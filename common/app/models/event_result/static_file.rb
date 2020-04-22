# encoding: utf-8
# frozen_string_literal: true

# EventResult::StaticFile description
class EventResult < ApplicationRecord
  class StaticFile < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :event_result, inverse_of: :static_files, touch: true

    has_one_attached :result_file

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================

  end
end
