# encoding: utf-8
# frozen_string_literal: true

module Admin
  class MeetingsController < Admin::ApplicationController
    # == Modules ============================================================
    include BetterRecord::Uploadable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :find_meeting, except: [ :index ]

    # == Actions ============================================================
    def index
      @meetings = authorize Meeting
      render json: @meetings if stale? @meetings
    end

    def registrations
      if request.post?
        status, messages = parse_registrations

        return render json: {
          message: messages
        }, status: 200
      else
        if (Time.zone.now + 1.hour) > @meeting.start_time
          Meeting::Registration::SendToLivestormJob.perform_later(@meeting.id)
        end
        download_registrations
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def find_meeting
        @meeting = authorize Meeting.find_by(id: params[:id])
      end

      def parse_registrations
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
              row = row.to_h.with_indifferent_access
              if row[:duration].present? || row[:duration_percentage].present?
                raise ActiveRecord::RecordNotFound unless user = User.find_by_dus_id(row[:dus_id])

                if row[:duration].blank?
                  if row[:duration_percentage].to_s =~ /100/
                    row[:duration] = '01:00:00'
                  else
                    row[:duration_percentage] = "0.#{row[:duration_percentage].gsub(/[^0-9]/, '').rjust(2, '0')}".to_d
                    row[:duration] = 3600 * row[:duration_percentage]
                    row[:duration] = "00:#{(row[:duration] / 60).to_i.to_s.rjust(2, '0')}:#{(row[:duration] % 60).to_s.rjust(2, '0')}"
                  end
                end

                [user, *user.related_users].each do |u|
                  if mtg = u.meeting_registrations.find_by(meeting_id: @meeting.id)
                    mtg.update(attended: true, duration: row[:duration].rjust(8, '0'))
                  end
                end
              end
            rescue
              puts $!.message
              puts $!.backtrace.first(10)
              # ImportError.create(upload_type: 'School', values: row.to_json)
              errors << $!.message
            end
          end

          if errors.present?
            return [
              500,
              errors
            ]
          else
            if params[:video].present? && @meeting.recording_link.blank?
              # unless Meeting.find_by(start_time: @meeting.start_time + 7.days)
              #   next_week = @meeting.dup
              #   next_week.start_time += 7.days
              #   next_week.save!
              # end

              @meeting.update(recording_link: params[:video])

              Meeting::FollowUpEmailsJob.perform_later(meeting_id: @meeting.id, staff_user_id: current_user.id)
            end
            return [200, 'File Uploaded']
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
      end

      def download_registrations
        csv_headers("meeting_registrations_#{@meeting.start_time}")

        self.response_body = Enumerator.new do |y|
          deflator = StreamCSVDeflator.new(y)

          deflator.stream %w[
            duration_percentage
            dus_id
            team
            name
            email
            phone
            category
            relation_to_athlete
            athlete_dus_id
            attended
          ]

          @meeting.registrations.each do |reg|
            u = reg.user
            rel_to_ath, ath_dus_id = nil
            begin
              ath = u.related_athlete
              rel_to_ath = u.is_athlete? ? 'self' : ath.relations.where(related_user_id: u.id).first.relationship
              ath_dus_id = u.is_athlete? ? u.dus_id : ath.dus_id
            rescue
              begin
                rel_to_ath = 'none'
                ath_dus_id = u.main_relation&.dus_id
              rescue
                rel_to_ath, ath_dus_id = nil
              end
            end

            deflator.stream [
              nil,
              u.dus_id,
              u.team&.name,
              u.full_name,
              u.ambassador_email,
              u.phone.to_s.gsub(/[^0-9]/, '').presence,
              u.category_title,
              rel_to_ath,
              ath_dus_id,
              reg.attended.to_s
            ]
          end

          deflator.close
        end
      end
  end
end
