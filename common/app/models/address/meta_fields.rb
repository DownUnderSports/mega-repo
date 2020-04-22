# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address'

class Address < ApplicationRecord
  # == Constants ============================================================
  META_FIELDS = %i[ student_list_id verified rejected ]
end
