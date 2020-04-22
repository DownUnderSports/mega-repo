# encoding: utf-8
# frozen_string_literal: true

module Admin
  module Accounting
    class RemitFormsController < ::Admin::ApplicationController
      # == Modules ============================================================
      include Filterable

      # == Class Methods ======================================================

      # == Pre/Post Flight Checks =============================================

      # == Actions ============================================================
      def index
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            base_remittances = remittance_list

            filter, options = filter_records(amount_regex: /total/, boolean_regex: /^re.*ed$/)

            base_remittances = (
              authorize filter ?
                base_remittances.where(filter, options.deep_symbolize_keys) :
                base_remittances
            )

            remittances = base_remittances.order(*get_sort_params, remit_number: :desc).offset((params[:page] || 0).to_i * 100).limit(100)

            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :total, base_remittances.unscoped.count('1')
              deflator.stream true, :remittances, '['

              i = 0
              remittances.each do |r|
                deflator.stream (i += 1) > 1, nil, {
                  remit_number: r.remit_number,
                  positive_amount: r.positive_amount.to_i.cents.to_s(true),
                  negative_amount: r.negative_amount.to_i.cents.to_s(true),
                  net_amount: r.net_amount.to_i.cents.to_s(true),
                  successful_amount: r.successful_amount.to_i.cents.to_s(true),
                  failed_amount: r.failed_amount.to_i.cents.to_s(true),
                  recorded: r.recorded,
                  reconciled: r.reconciled,
                }
              end

              deflator.stream false, nil, ']'

              deflator.close
            end
          end
          format.csv do
            # csv_headers('remit_number_totals')
            @remittance_list =
              remittance_list.
              order(remit_number: :desc)

            # puts render_to_string(:template => "admin/accounting/remit_forms/index.csv.csvrb")

            render csv: "index", filename: "remit_number_totals", with_time: true
          end
        end
      end

      # == Cleanup ============================================================

      # == Utilities ==========================================================
      def show
        respond_to do |format|
          format.html { fallback_index_html }
          format.json do
            @remit_number = params[:id]
            @remittance = Payment::Remittance.find_by(remit_number: @remit_number) || Payment::Remittance.new(remit_number: @remit_number)
            @payments = Payment.includes(:user, line_items: [user: :team]).where(remit_number: @remit_number).order(:created_at)
            @total_received = ((@payments.flat_map {|pmt| (pmt.items.where('amount > 0').sum(:amount) || 0) }.reduce(&:+)) || 0).to_i.cents
            @total_returned = ((@payments.flat_map {|pmt| (pmt.items.where('amount < 0').sum(:amount) || 0) }.reduce(&:+)) || 0).to_i.cents
            @total_net = (@total_received + @total_returned)

            return render json: {
              remit_number: @remit_number,
              remittance: @remittance,
              payments: @payments,
              received: @total_received,
              returned: @total_returned,
              net: @total_net
            }
          end
        end

      end

      def update
        remittance = Payment::Remittance.find_by(remit_number: params[:id]) || Payment::Remittance.new(remit_number: params[:id])

        success = remittance.save && remittance.update(whitelisted_remittance_params)
        errors = remittance.errors.full_messages

        return render json: { errors: errors || [] }, status: success ? 200 : 500
      end

      private
        def whitelisted_filter_params
          params.permit(allowed_keys)
        end

        def allowed_keys
          @allowed_keys ||= [
            :remit_number,
            :positive_amount,
            :negative_amount,
            :net_amount,
            :successful_amount,
            :failed_amount,
            :recorded,
            :reconciled,
          ].freeze
        end

        def default_sort_order
          []
        end

        def whitelisted_remittance_params
          params.require(:remittance).permit(:recorded, :reconciled)
        end

        def remittance_list
          ::Accounting::Views::Remittance.all
        end
    end
  end
end
