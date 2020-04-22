# encoding: utf-8
# frozen_string_literal: true

module API
  class MeetingsController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def index
      @meetings = Meeting.order(:start_time, :id).select(:id, :start_time, :duration, :category)

      if stale? @meetings
        return render json: {
          meetings: (
            @meetings.map do |meeting|
              {
                id: meeting.id,
                category: Meeting::Category.titleize(meeting.category),
                **time_hash(meeting)
              }
            end
          ),
          version: last_update
        }
      end
    end

    def countdown
      @meeting = Meeting.find_by(id: params[:id])

      return render json: time_hash(@meeting), status: 200 if stale? @meeting
    rescue
      return render json: {
      }, status: 404
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def time_hash(mtg)
        utc = mtg.start_time.utc
        {
          full: utc,
          date: utc.to_date.to_s,
          time: utc.strftime("%r"),
          year: utc.year,
          month: utc.month - 1,
          day: utc.day,
          hour: utc.hour,
          minutes: utc.min,
          seconds: utc.sec,
          array: [ utc.year, utc.month - 1, utc.day, utc.hour, utc.min, utc.sec ]
        }
      end

      def last_update
        begin
          Meeting.order(updated_at: :desc).select(:updated_at).limit(1).pluck(:updated_at).first.utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end
  end
end
