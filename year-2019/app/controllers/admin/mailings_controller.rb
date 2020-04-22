# encoding: utf-8
# frozen_string_literal: true

module Admin
  class MailingsController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [:show]

    # == Actions ============================================================
    def version
      return head (last_update == params[:version]) ? 204 : 410
    end

    def index
      mailings = authorize Mailing.order(:created_at).where(user: @found_user)

      if stale? mailings
        headers["X-Accel-Buffering"] = 'no'

        expires_now
        headers["Content-Type"] = "application/json; charset=utf-8"
        headers["Content-Disposition"] = 'inline'
        headers["Content-Encoding"] = 'deflate'
        headers["Last-Modified"] = Time.zone.now.ctime.to_s

        self.response_body = Enumerator.new do |y|
          deflator = StreamJSONDeflator.new(y)

          deflator.stream false, :version, last_update
          deflator.stream true, :mailings, '['

          i = 0
          mailings.map do |m|
            deflator.stream (i += 1) > 1, nil, {
              id: m.id,
              user_id: m.user_id,
              category: m.category&.titleize,
              address: Address.new(m.address).inline,
              failed: m.failed,
              is_home: m.is_home,
              sent: m.sent.presence&.strftime('%a %b %d'),
            }
          end

          deflator.stream false, nil, ']'

          deflator.close
        end
      end
    end

    def show
      @mailings = authorize Mailing.where('category ilike ?', "%#{params[:id].to_s.underscore}%")

      csv_headers("mailings-#{params[:id]}")

      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        deflator.stream %i[
          url
          dus_id
          main_dus_id
          user_category
          first
          middle
          last
          suffix
          print_name
          meeting_date
          deposit_date
          mailing_category
          street
          street_2
          street_3
          city
          state
          zip
          country
          inline
        ]

        @mailings.split_batches do |b|
          b.each do |m|
            u = m.user
            deflator.stream [
              u.url(true),
              u.dus_id,
              u.main_relation&.dus_id,
              u.category_title,
              u.first,
              u.middle,
              u.last,
              u.suffix,
              u.print_names,
              u.meeting_registrations.where(attended: true).order(:created_at).limit(1).take&.meeting&.start_time&.to_date&.to_s,
              u.traveler&.items&.order(:created_at)&.limit(1)&.take&.created_at&.to_date&.to_s,
              m.category,
              m.street,
              m.street_2,
              m.street_3,
              m.city,
              m.state,
              m.zip,
              m.country,
              Address.new(m.address).inline
            ]
          end
        end

        deflator.close
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def last_update
        begin
          return nil unless @found_user.mailings.count > 0
          @found_user.mailings.
            order(updated_at: :desc).
            select(:updated_at).
            limit(1).
            pluck(:updated_at).
            first.utc.iso8601
        rescue
          puts $!.message
          puts $!.backtrace
          nil
        end
      end

      def lookup_user
        if !request.format.html?
          @found_user = authorize User.get(params[:user_id])
        end
      end
  end
end
