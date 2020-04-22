# encoding: utf-8
# frozen_string_literal: true

require_dependency 'address'

class Address < ApplicationRecord
  # == Constants ============================================================
  SELECTION_SQL = <<-SQL
    states.abbr = ?
    AND
    addresses.verified = 't'
    AND
    EXISTS (
      SELECT * FROM address_variants
      WHERE address_variants.address_id = addresses.id
      AND array_upper(candidate_ids) IS NOT NULL
    )
  SQL
end
