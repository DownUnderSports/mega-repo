# encoding: utf-8
# frozen_string_literal: true

class ViewTracker < ApplicationRecord
  # == Constants ============================================================

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Relationships ========================================================

  # == Validations ==========================================================

  # == Scopes ===============================================================

  # == Callbacks ============================================================

  # == Boolean Class Methods ================================================

  # == Class Methods ========================================================
  def self.refresh_view(view, concurrently: true, async: true)
    if async
      begin
        RefreshViewJob.perform_later(view, concurrently: concurrently)
      ensure
        return true
      end
    end

    tracker = nil
    begin
      tracker = find_or_create_by!(name: view)
      return false if tracker.running
      tracker.update(running: true)
      successful, err = nil

      %w[ public year_2019 year_2020 ].each do |year|
        begin
          self.connection.execute(%(REFRESH MATERIALIZED VIEW #{concurrently ? 'CONCURRENTLY ' : ''}#{year}.#{view}))
          successful = true
        rescue
          err = $!
        end
      end

      raise err unless successful

      tracker.update(running: false, last_refresh: Time.zone.now)
    rescue
      puts $!.message
      puts $!.backtrace
      find_by(name: view)&.destroy
      tracker = nil
    rescue Exception
      puts $!.message
      puts $!.backtrace
      find_by(name: view)&.destroy rescue nil
      raise
    end
    return tracker&.last_refresh&.in_time_zone
  end

  def self.last_refresh(view)
    find_by(name: view)&.last_refresh&.in_time_zone
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================

end
