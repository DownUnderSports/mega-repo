# encoding: utf-8
# frozen_string_literal: true

namespace :addresses do
  desc 'Normalize address time zones'
  task fix_tz: :environment do
    Address.where('tz_offset < 30 AND tz_offset > -30').order(:id).split_batches do |b|
      b.each do |a|
        if a.tz_offset != normalize_tz_offset(a.tz_offset)
          puts a.inline
          a.update_columns(tz_offset: normalize_tz_offset(a.tz_offset))
          a.flight_airports.map(&:touch)
          a.schools.map(&:touch)
          a.users.map(&:touch)
        end
      end
    end
  end
end
