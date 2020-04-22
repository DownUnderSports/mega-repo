# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Assignments
    class RespondsController < ::Admin::ApplicationController
      # == Modules ============================================================
      include BetterRecord::Uploadable
      include Filterable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do

            base_assignments = Staff::Assignment::Views::Respond

            if params[:user_id].present?
              begin
                user_id = User.get(params[:user_id]).id
                base_assignments = base_assignments.where(user_id: user_id)
              rescue
                base_assignments = base_assignments.where('1=0')
              end
            else
              filter, options = filter_records boolean_regex: /^(visited|watched|viewed|locked)$/, interval_regex: /duration/

              base_assignments = authorize filter ?
                base_assignments.where(filter, options.deep_symbolize_keys) :
                base_assignments
            end

            @assignments = base_assignments.
              order(*get_sort_params, :responded_at, :created_at, :name, :id).
              offset((params[:page] || 0).to_i * 100).
              limit(100)

            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :total, base_assignments.count('1')
              deflator.stream true, :assignments, '['

              i = 0
              @assignments.each do |a|
                deflator.stream (i += 1) > 1, nil, {
                  assigned_to_full_name: a.assigned_to_full_name,
                  assigned_by_full_name: a.assigned_by_full_name,
                  created_at: a.created_at&.strftime('%b %d @ %r'),
                  duration: a.duration,
                  dus_id: a.dus_id,
                  follow_up_date: a.follow_up_date&.strftime('%b %d'),
                  id: a.id,
                  interest_id: a.interest_id,
                  interest_level: a.interest_level,
                  last_messaged_at: a.last_messaged_at&.strftime('%b %d @ %r'),
                  last_viewed_at: a.last_viewed_at&.strftime('%b %d @ %r'),
                  locked: a.locked,
                  message_count: a.message_count,
                  name: a.name,
                  other_message_count: a.other_message_count,
                  pre_meeting_message_count: a.pre_meeting_message_count,
                  post_meeting_message_count: a.post_meeting_message_count,
                  registered_at: a.registered_at&.strftime('%b %d @ %r'),
                  responded_at: a.responded_at&.strftime('%b %d @ %r'),
                  team_name: a.team_name,
                  tz_offset: a.tz_offset,
                  url: a.admin_url,
                  viewed: a.viewed,
                  viewed_at: a.viewed_at&.strftime('%b %d @ %r'),
                  visited: a.visited,
                  watched: a.watched,
                  watched_at: a.watched_at&.strftime('%b %d @ %r'),
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
          format.csv do
            return head 403 unless current_user && current_user.is_staff? && current_user.staff.check(:management)

            render csv: "index", filename: "responds_to_assign", with_time: true
          end
        end
      rescue NoMethodError
        return not_authorized([
          'Invalid',
          $!.message
        ], 422)
      end

      def create
        if current_user && current_user.is_staff? && current_user.staff.check(:management)
          status, messages = parse_respond_assignments

          Staff::Assignment::Views::Respond.reload

          return render json: {
            message: messages.first,
            errors: (status > 200) && messages,
          }, status: 200
        else
          return render json: {
            message: 'Unauthorized',
            errors: ['You are not authorized to perform this action'],
          }, status: 200
        end
      end

      def reassign
        if current_user && current_user.is_staff? && current_user.staff.check(:management)
          status, messages = parse_reassignments

          Staff::Assignment::Views::Respond.reload

          return render json: {
            message: messages.first,
            errors: (status > 200) && messages,
          }, status: 200
        else
          return render json: {
            message: 'Unauthorized',
            errors: ['You are not authorized to perform this action'],
          }, status: 200
        end
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      private
        def parse_reassignments
          errors = []
          begin
            @assignments = Staff::Assignment::Views::Respond
            @assignments.batch_updates = true

            raise "Invalid Staff Selection" unless params[:staff_id].present? && User.get(params[:staff_id])&.is_staff?

            filter, options = filter_records boolean_regex: /^(visited|watched|viewed|locked)$/, interval_regex: /duration/

            @assignments = authorize filter ?
              @assignments.where(filter, options.deep_symbolize_keys) :
              @assignments

            @assignments.order(:id).split_batches do |b|
              b.each do |a|
                begin
                  raise "Assignment Locked to #{a.assigned_to_full_name}: #{a.id} #{a.name} #{a.dus_id}" if a.locked?
                  a.update!(assigned_to_id: params[:staff_id])
                rescue
                  puts $!.message
                  puts $!.backtrace.first(10)

                  errors << $!.message
                end
              end
            end
          rescue
            errors << $!.message
          ensure
            Staff::Assignment::Views::Respond.batch_updates = false
            Staff::Assignment::Views::Respond.reload
          end

          if errors.present?
            return [
              500,
              errors
            ]
          else
            return [200, ['All Assignments Reassigned']]
          end
        end

        def parse_respond_assignments
          uploaded = whitelisted_upload_params[:file]

          @file_stats = {
            name: uploaded.original_filename,
            "mime-type" => uploaded.content_type,
            size: view_context.number_to_human_size(uploaded.size)
          }

          if verify_file(whitelisted_upload_params, :file)
            uploaded = BetterRecord::Encoder.new(uploaded.read).to_utf8
            errors = []
            CSV.parse(uploaded, headers: true, encoding: 'utf-8').each do |row|
              begin
                row = row.to_h.symbolize_keys
                if row[:staff_dus_id].present?
                  user = nil, staff = nil
                  raise "#{staff ? 'User' : 'Staff'} not found: #{row[staff ? :dus_id : :staff_dus_id]}" unless
                    (staff = User.get(row[:staff_dus_id])) &&
                    (user = User.joins(:interest).includes(:interest, :traveler).get(row[:dus_id]))

                  raise "User already assigned: #{user.dus_id}" if
                    Staff::Assignment.find_by(user: user, reason: 'Respond')

                  unneeded = !!user.traveler || !(user.interest.contactable)

                  Staff::Assignment.create!(
                    user: user,
                    assigned_to: staff,
                    assigned_by: current_user,
                    unneeded: unneeded,
                    unneeded_at: unneeded.presence && user.traveler&.created_at,
                    reason: 'Respond'
                  )
                end
              rescue
                puts $!.message
                puts $!.backtrace.first(10)

                errors << $!.message
              end
            end

            if errors.present?
              return [
                500,
                errors
              ]
            else
              return [200, ['File Uploaded']]
            end
          else
            return [
              422,
              [
                'something went wrong',
                'Only csv files with the correct headers are supported',
                "content type: #{whitelisted_upload_params[:file].content_type}", "file name: #{whitelisted_upload_params[:file].original_filename}"
              ]
            ]
          end
        rescue
          p $!.message
          p $!.backtrace
          [
            500,
            [$!.message]
          ]
        end

        def default_sort_order
          []
        end

        def whitelisted_filter_params
          params.permit(allowed_keys)
        end

        def allowed_keys
          @allowed_keys ||= [
            :assigned_to_full_name,
            :created_at,
            :duration,
            :dus_id,
            :follow_up_date,
            :interest_id,
            :interest_level,
            :last_messaged_at,
            :message_count,
            :pre_meeting_message_count,
            :post_meeting_message_count,
            :other_message_count,
            :name,
            :registered_at,
            :responded_at,
            :team_name,
            :tz_offset,
            :locked,
            :viewed,
            :viewed_at,
            :visited,
            :last_viewed_at,
            :watched,
            :watched_at
          ].freeze
        end
    end
  end
end
