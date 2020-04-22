# encoding: utf-8
# frozen_string_literal: true

module Admin
  class ReturnedMailsController < Admin::ApplicationController
    # == Modules ============================================================
    include Filterable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          filter, options = filter_records(boolean_regex: /allowed|closed/, date_regex: /sent/) do |position|
            position.after do |prefix, param, value, options, not_like, separator|
              case true
              when !!(param.to_s =~ /category/) && (value.size == 1)
                options[:filter] << "#{separator}(category ilike :#{prefix}category)"
                options["#{prefix}category"] = "#{CATEGORIES[value.first.downcase.to_sym]}%"
              when !!(param.to_s =~ /home|foreign/)
                if value.present?
                  options[:filter] << "#{separator}(is_#{param.to_s =~ /home/ ? 'home' : 'foreign'} = '#{Boolean.parse(value) ? 't' : 'f'}')"
                end
              else
                false
              end
            end
          end

          base_mailings = authorize Mailing.joins(
            <<-SQL.gsub(/\s*\n?\s+/m, ' ')
              INNER JOIN (
                SELECT
                  id user_pk,
                  dus_id
                FROM users
              ) users
              ON users.user_pk = mailings.user_id
            SQL
          ).select('mailings.*', 'users.dus_id')

          base_mailings =
            filter ?
              base_mailings.where(filter, options.deep_symbolize_keys) :
              base_mailings

          mailings = base_mailings.order(*get_sort_params).offset((params[:page] || 0).to_i * 100).limit(100)

          headers["X-Accel-Buffering"] = 'no'

          expires_now
          headers["Content-Type"] = "application/json; charset=utf-8"
          headers["Content-Disposition"] = 'inline'
          headers["Content-Encoding"] = 'deflate'
          headers["Last-Modified"] = Time.zone.now.ctime.to_s

          self.response_body = Enumerator.new do |y|
            deflator = StreamJSONDeflator.new(y)

            deflator.stream false, :total, base_mailings.count(:id)
            deflator.stream true, :mailings, '['

            i = 0
            mailings.each do |m|
              deflator.stream (i += 1) > 1, nil, {
                id: m.id,
                dus_id: m.dus_id.presence,
                category: m.category,
                sent: m.sent.to_s,
                failed: m.failed,
                is_home: m.is_home,
                is_foreign: m.is_foreign,
                street: m.street,
                street_2: m.street_2,
                street_3: m.street_3,
                city: m.city,
                state: m.state,
                zip: m.zip,
                country: m.country,
              }
            end

            deflator.stream false, nil, ']'

            deflator.close
          end
        end
        format.csv do
          @mailings = authorize Mailing.joins(:user).includes(:user)

          render  csv: "index",
                  filename: "user_possible_mailings_to_mark",
                  with_time: true
        end
      end
    end

    def show
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          @mailing = authorize Mailing.find_by(id: params[:id])

          render json: params[:effects].present? ? {
            count: @mailing.__send__(:"#{params[:effects]}_effects")
          } : {
            id: @mailing.id,
            address: Address.new(@mailing.address).to_shipping(true),
            auto: @mailing.auto?,
            category: @mailing.category&.titleize,
            explicit: @mailing.explicit?,
            failed: @mailing.failed?,
            is_home: @mailing.is_home?,
            is_foreign: @mailing.is_foreign?,
            printed: @mailing.printed?,
            sent: @mailing.sent.presence&.strftime('%b %d, %Y'),
            user_id: @mailing.user_id,
            school_id: @mailing.user&.main_school&.id
          }.null_to_str
        end
      end
    rescue NoMethodError
      return not_authorized([
        'Mailing not found',
        $!.message
      ], 422)
    end

    def update
      return not_authorized(errors, 422)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def default_sort_order
        [ :category, 'state' ]
      end

      def whitelisted_filter_params
        params.permit(allowed_keys)
      end

      def allowed_keys
        @allowed_keys ||= [
          :id,
          :dus_id,
          :category,
          :sent,
          :is_home,
          :is_foreign,
          :street,
          :street_2,
          :street_3,
          :city,
          :state,
          :zip,
          :country,
        ].freeze
      end

      def direction_maps
        @direction_maps ||= {
          id: :id,
          dus_id: 'users.dus_id',
          category: :category,
          sent: :sent,
          is_home: :is_home,
          is_foreign: :is_foreign,
          street: :street,
          street_2: :street_2,
          street_3: :street_3,
          city: :city,
          state: :state,
          zip: :zip,
          country: :country,
        }.freeze
      end

      CATEGORIES = {
        f: :fundraising,
        h: :holiday,
        i: :invite,
        k: :infokit,
      }

      class NotSpecificEnough < StandardError
      end
  end
end
