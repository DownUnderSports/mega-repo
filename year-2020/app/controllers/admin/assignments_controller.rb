# encoding: utf-8
# frozen_string_literal: true

module Admin
  class AssignmentsController < ::Admin::ApplicationController
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
            where(user_id: User.get(params[:user_id]).id)

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
                  completed: a.completed,
                  unneeded: a.unneeded,
                  assigned_to: a.assigned_to.basic_name,
                  assigned_by: a.assigned_by.basic_name,
                  reason: a.reason,
                  follow_up_date: a.follow_up_date,
                  assigned_at: a.created_at.strftime('%Y-%m-%d @ %I:%M %p'),
                  completed_at: a.completed && a.completed_at&.strftime('%Y-%m-%d @ %I:%M %p'),
                  unneeded_at: a.unneeded && a.unneeded_at&.strftime('%Y-%m-%d @ %I:%M %p'),
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
      if whitelisted_assignment_update_params[:assigned_to_id] == auto_worker&.id
        return render json: { success: false }, status: 500
      end
      return run_update do
        Staff::Assignment.
          find_by(id: params[:id])&.
          update(whitelisted_assignment_update_params)
      end
    end

    def incomplete
      return run_update do
        Staff::Assignment.
          find_by(id: params[:id])&.
          update(completed: false)
      end
    end

    def completed
      return run_update do
        Staff::Assignment.
          find_by(id: params[:id])&.
          update(completed: true)
      end
    end

    def unneeded
      return run_update do
        Staff::Assignment.
          find_by(id: params[:id])&.
          update(unneeded: true)
      end
    end

    def needed
      return run_update do
        Staff::Assignment.
          find_by(id: params[:id])&.
          update(unneeded: false)
      end
    end

    def visited
      return run_update do
        Staff::Assignment.
          find_by(id: params[:id])&.
          visits.create
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def run_update(&block)
        begin
          success = !!(block.call)
        rescue
          success = false
        end
        return render json: { success: success }, status: success ? 200 : 500
      end

      def whitelisted_assignment_update_params
        params.require(:assignment).permit(:completed, :unneeded, :reviewed, :visited, :locked, :follow_up_date, :assigned_to_id)
      end
  end
end
