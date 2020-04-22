# encoding: utf-8
# frozen_string_literal: true

require_dependency 'traveler/base_debit'

class Traveler < ApplicationRecord
  class BaseDebit < ApplicationRecord
    # == Constants ============================================================
    SingleRoom = self.find_by(name: 'Single Room')
  end
end
