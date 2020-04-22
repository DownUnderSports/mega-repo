# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user/uniform_order'

class User < ApplicationRecord
  class UniformOrder < ApplicationRecord
    # == Constants ============================================================
    class PresenceAndFormatValidator < ActiveModel::EachValidator
      def validate_each(record, attribute, value)
        if value.blank?
          record.errors.add attribute, "is required"
        else
          record.errors.add attribute, "invalid value" unless value =~ /\A([MW]-)?([SML]|XS|\d?X+L)\z/
        end
      end
    end
  end
end
