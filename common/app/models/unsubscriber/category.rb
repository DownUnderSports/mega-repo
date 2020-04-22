# encoding: utf-8
# frozen_string_literal: true

require_dependency 'unsubscriber'

class Unsubscriber < ApplicationRecord
  module Category
    ENUM = {
      C: 'C',
      E: 'E',
      M: 'M',
      T: 'T',
      Call: 'C',
      call: 'C',
      Email: 'E',
      email: 'E',
      Mail: 'M',
      mail: 'M',
      Text: 'T',
      text: 'T'
    }.freeze

    TITLECASE = {
      'C' => 'Call',
      'I' => 'Email',
      'M' => 'Mail',
      'T' => 'Text',
    }.freeze

    def self.titleize(category)
      TITLECASE[convert_to_unsubscriber_category(category)]
    end

    def self.convert_to_unsubscriber_category(value)
      case value.to_s
      when /^[Ee]/
        'E'
      when /^[Mm]/
        'M'
      when /^[Tt]/
        'T'
      when /^[Cc]/
        'C'
      else
        'E'
      end
    end

    module TableDefinition
      def unsubscriber_category(*args, **opts)
        args.each do |name|
          column name, :unsubscriber_category, **opts
        end
      end
    end

    class Type < ActiveRecord::Type::Value

      def cast(value)
        convert_to_unsubscriber_category(value)
      end

      def deserialize(value)
        super(convert_to_unsubscriber_category(value))
      end

      def serialize(value)
        super(convert_to_unsubscriber_category(value))
      end

      private
        def convert_to_unsubscriber_category(value)
          Unsubscriber::Category.convert_to_unsubscriber_category(value)
        end
    end
  end
end
