# encoding: utf-8
# frozen_string_literal: true

require_dependency 'payment'

class Payment < ApplicationRecord
  module Transaction
  end
end
