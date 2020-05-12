# encoding: utf-8
# frozen_string_literal: true

require_dependency 'fundraising_idea'

# FundraisingIdea::Image description
class FundraisingIdea < ApplicationRecord
  class Image < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :fundraising_idea, inverse_of: :images
    has_one_attached :file
    delegate_missing_to :file

    # == Validations ==========================================================

    # == Scopes ===============================================================
    scope :ordered, -> { order(display_order: :asc, created_at: :asc) }

    # == Callbacks ============================================================
    after_commit :touch_idea

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    private
      def touch_idea
        self.fundraising_idea&.touch
      end

  end
end
