# encoding: utf-8
# frozen_string_literal: true

module Admin
  class SchoolsController < Admin::ApplicationController
    # == Modules ============================================================
    include Filterable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          filter = nil
          options = {}
          allowed = whitelisted_filter_params
          allowed.each do |param, value|
            str = filter ? +' AND ' : +''
            filter ||= +''

            case true
            when value.to_s.upcase == 'NULL'
              filter << "#{str}(#{param} IS #{not_like ? 'NOT ' : ''}NULL)"

            when !!(param.to_s =~ /state/)

            else
              value = value.to_s.upcase.sub('-', '') if param.to_s =~ /dus/
              filter << "#{str}(#{param} ilike :#{param})"
              options[param] = "%#{value}%"
            end
          end

          filter, options = filter_records(boolean_regex: /allowed|closed/) do |position|
            position.after do |prefix, param, value, options, not_like, separator|
              if param.to_s =~ /state/
                options[:filter] << "#{separator}(states.abbr #{not_like ? 'NOT ' : ''}LIKE :#{prefix}#{param})"
                options["#{prefix}#{param}"] = "%#{value}%".upcase
                options
              end
            end
          end

          # filter_state_or_sport = allowed[:state].present? || allowed[:sport].present?
          base_schools = authorize School.joins(address: :state)

          base_schools =
            filter ?
              base_schools.where(filter, options.deep_symbolize_keys) :
              base_schools

          schools = base_schools.order(*get_sort_params).offset((params[:page] || 0).to_i * 100).limit(100)

          headers["X-Accel-Buffering"] = 'no'

          expires_now
          headers["Content-Type"] = "application/json; charset=utf-8"
          headers["Content-Disposition"] = 'inline'
          headers["Content-Encoding"] = 'deflate'
          headers["Last-Modified"] = Time.zone.now.ctime.to_s

          self.response_body = Enumerator.new do |y|
            deflator = StreamJSONDeflator.new(y)

            deflator.stream false, :total, base_schools.count('1')
            deflator.stream true, :schools, '['

            i = 0
            schools.each do |s|
              deflator.stream (i += 1) > 1, nil, {
                id: s.id,
                pid: s.pid,
                name: s.name,
                allowed: s.allowed,
                allowed_home: s.allowed_home,
                closed: s.closed,
                street: s.address.street,
                city: s.address.city,
                state: s.address.state&.abbr,
                zip: s.address.zip
              }
            end

            deflator.stream false, nil, ']'

            deflator.close
          end
        end
        format.csv do
          @schools = authorize School.all.includes(address: :state)

          render csv: 'index',
                 filename: 'all_schools',
                 with_time: true
        end
      end
    end

    def show
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          school = authorize School[params[:id]]
          return render json: school.to_json(include: :address)
        end
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def whitelisted_filter_params
        params.permit(allowed_keys)
      end

      def allowed_keys
        @allowed_keys ||= [
          :pid,
          :name,
          :allowed,
          :allowed_home,
          :closed,
          :street,
          :city,
          :state,
          :zip
        ].freeze
      end

      def default_sort_order
        [ :name, 'states.abbr' ]
      end

      def direction_maps
        @direction_maps ||= {
          pid: :pid,
          name: :name,
          allowed: :allowed,
          allowed_home: :allowed_home,
          closed: :closed,
          street: 'addresses.street',
          city: 'addresses.city',
          state: 'states.abbr',
          zip: 'addresses.zip'
        }.freeze
      end

  end
end
