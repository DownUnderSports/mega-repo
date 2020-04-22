# encoding: utf-8
# frozen_string_literal: true

module Admin
  class AssignmentsController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.any do
          @assignments = Staff::Assignment.
            joins(:assigned_by, :assigned_to).
            includes(:assigned_by, :assigned_to).
            where(user_id: User.get(params[:user_id]).id, completed: false)

          if stale? @assignments
            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :assignments, '['

              i = 0
              @assignments.each do |a|

                deflator.stream (i += 1) > 1, nil, {
                  id: a.id,
                  assigned_to_id: a.assigned_to_id,
                  visited: a.visited,
                  locked: a.locked,
                  assigned_to: a.assigned_to.basic_name,
                  assigned_by: a.assigned_by.basic_name,
                  reason: a.reason,
                  follow_up_date: a.follow_up_date,
                  assigned_at: a.created_at.strftime('%Y-%m-%d @ %I:%M %p')
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
        end
      end
    end

    def update
      return not_authorized("CANNOT ADD/REMOVE/MODIFY ASSIGNMENTS IN PREVIOUS YEARS", 422)
    end

    def completed
      return update
    end

    def unneeded
      return update
    end

    def visited
      return update
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
