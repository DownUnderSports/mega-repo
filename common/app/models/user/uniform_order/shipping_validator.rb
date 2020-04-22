# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/uniform_order'

class User < ApplicationRecord
  class UniformOrder < ApplicationRecord
    # == Constants ============================================================
    class ShippingValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        if value.blank?
          record.errors.add attribute, "is required"
        else
          validated_vals = [
            :street_1,
            :city,
            :state_abbr,
            :zip,
          ]
          transformed = value.to_h.with_indifferent_access
          validated_vals.each {|k| record.errors.add :shipping, "#{k} is required" if transformed[k].blank?}
        end
      end
    end
  end
end
