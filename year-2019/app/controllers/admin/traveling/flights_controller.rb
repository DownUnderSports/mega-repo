# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Traveling
    class FlightsController < Admin::ApplicationController
      # == Modules ============================================================

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index

        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            # return render json: (dates.map do |k, v|
            #   [
            #     "Departing: #{k}",
            #     v.map {|sk, sv| ["Returning: #{sk}", sv]}.to_h
            #   ]
            # end.to_h)
            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              i = 0
              dates.each do |k, v|
                deflator.stream (i += 1) > 1, "Departing: #{k}", '{'

                n = 0
                v.each do |sk, sv|
                  deflator.stream (n += 1) > 1, "Returning: #{sk}", sv
                end

                deflator.stream false, nil, '}'
              end

              deflator.close
            end
          end
          format.csv do
            render  csv: 'index',
                    filename: 'current_domestic_list',
                    with_time: true
          end
        end
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      def dates
        return @dates if @dates.present?
        @dates = {}
        own_d = Traveler::BaseDebit.own_domestic
        has_d = Traveler::BaseDebit.domestic
        @unassigned = []
        @ground_only = []
        test_users = [test_user&.id, auto_worker&.id, *test_user.relations.pluck(:related_user_id)].select(&:present?).uniq
        Traveler.with_flights do |t|
          next if test_users.any?(t.user_id)

          @dates[t.departing_date.to_s] ||= {}
          @dates[t.departing_date.to_s][t.returning_date.to_s] ||= {}
          if t.debits.find_by(base_debit: own_d)
            @dates[t.departing_date.to_s][t.returning_date.to_s]['LAX-LAX'] ||= 0
            @dates[t.departing_date.to_s][t.returning_date.to_s]['LAX-LAX'] += 1
          elsif (td = t.debits.find_by(base_debit: has_d))
            flight_path = td.name.split(':').last.strip
            @dates[t.departing_date.to_s][t.returning_date.to_s][flight_path] ||= 0
            @dates[t.departing_date.to_s][t.returning_date.to_s][flight_path] += 1
          else
            @dates[t.departing_date.to_s][t.returning_date.to_s]['_UNASSIGNED'] ||= 0
            @dates[t.departing_date.to_s][t.returning_date.to_s]['_UNASSIGNED'] += 1
            @unassigned << t
          end
        end

        Traveler.without_flights do |t|
          next if test_users.any?(t.user_id)

          @dates[t.departing_date.to_s] ||= {}
          @dates[t.departing_date.to_s][t.returning_date.to_s] ||= {}
          @dates[t.departing_date.to_s][t.returning_date.to_s]['_GROUND_ONLY'] ||= 0
          @dates[t.departing_date.to_s][t.returning_date.to_s]['_GROUND_ONLY'] += 1
          @ground_only << t
        end
        @dates
      end

    end
  end
end
