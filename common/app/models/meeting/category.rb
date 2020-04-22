# encoding: utf-8
# frozen_string_literal: true

class Meeting < ApplicationRecord
  module Category
    ENUM = {
      I: 'I',
      i: 'I',
      Information: 'I',
      information: 'I',
      D: 'D',
      d: 'D',
      Departure: 'D',
      departure: 'D',
      S: 'S',
      s: 'S',
      Staff: 'S',
      staff: 'S',
      A: 'A',
      a: 'A',
      Athlete: 'A',
      athlete: 'A',
      P: 'P',
      p: 'P',
      Parent: 'P',
      parent: 'P',
      F: 'F',
      f: 'F',
      Fundraising: 'F',
      fundraising: 'f'
    }.freeze

    TITLECASE = {
      'I' => 'Information',
      'D' => 'Departure',
      'S' => 'Staff',
      'A' => 'Athlete',
      'P' => 'Parent',
      'F' => 'Fundraising'
    }.freeze

    def self.titleize(category)
      TITLECASE[convert_to_meeting_category(category)]
    end

    def self.convert_to_meeting_category(value)
      case value.to_s
      when /^[Ii]/
        'I'
      when /^[Dd]/
        'D'
      when /^[Ss]/
        'S'
      when /^[Aa]/
        'A'
      when /^[Pp]/
        'P'
      when /^[Ff]/
        'F'
      else
        'I'
      end
    end

    module TableDefinition
      def meeting_category(*args, **opts)
        args.each do |name|
          column name, :meeting_category, **opts
        end
      end
    end

    class Type < ActiveRecord::Type::Value

      def cast(value)
        convert_to_meeting_category(value)
      end

      def deserialize(value)
        super(convert_to_meeting_category(value))
      end

      def serialize(value)
        super(convert_to_meeting_category(value))
      end

      private
        def convert_to_meeting_category(value)
          Meeting::Category.convert_to_meeting_category(value)
        end
    end
  end
end
