# encoding: utf-8
# frozen_string_literal: true

module Admin
  class UniformOrdersController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================
    layout 'uniform_order'

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_uniform_order, only: [ :show ]
    before_action :packing_slip

    # == Actions ============================================================
    def index
      expires_now

      respond_to do |format|
        format.html do
          if params[:sent_date].present? || params[:sport].present?
            return redirect_to next_uniform_order || admin_uniform_orders_path, status: 303
          end
        end
        format.csv do
          render  csv: 'index',
                  filename: params[:sport].present? ? "uniform_orders-#{params[:sport]}" : "uniform_submission_counts",
                  with_time: true
        end
        format.any do
          return redirect_to admin_uniform_orders_path(format: :html), status: 303
        end
      end
    end

    def stamps
      expires_now

      respond_to do |format|
        format.html do
          if params[:sent_date].present? && params[:sport].present?
            return redirect_to stamps_admin_uniform_orders_path(format: :csv, sent_date: params[:sent_date], sport: params[:sport]), status: 303
          end
        end
        format.csv do
          render  csv: 'stamps',
                  filename: "uniform_orders-stamps-#{params[:sport].presence || 'history'}",
                  with_time: true
        end
      end
    end

    def show
      @title = "uniform-order.#{@uniform_order.sport.abbr_gender}.#{@uniform_order.id + 1000}"
      return render pdf: "uniform_order_#{Time.now.to_s(:db).gsub(/\s/, '_')}", layout: 'uniform_order', show_as_html: true
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
    def lookup_uniform_order
      return @uniform_order if @uniform_order

      @uniform_order = User::UniformOrder.find(params[:id].to_i - 1000)
      if params.key?(:direct_print)
        next_uniform_order
        @direct_print = true
      end
    end

    def orders
      return @orders if @orders

      @orders = User::UniformOrder.order(:id)
      if params[:sent_date].present?
        time = Time.zone.parse(params[:sent_date])
        @orders = @orders.where(%Q(submitted_to_shop_at BETWEEN :start_time AND :end_time), start_time: time.midnight, end_time: time.end_of_day)
      end
      if params[:sport].present?
        sport = Sport[params[:sport]]&.id || Sport.where(abbr: params[:sport].to_s.upcase).select(:sport_id)
        @orders = @orders.where(sport_id: sport)
      end
      @orders
    end

    def next_uniform_order
      @next_uniform_order || get_next_uniform_order
    end

    def get_next_uniform_order
      @next_uniform_order = orders.where('id > ?', @next_uniform_order&.id || @uniform_order&.id || 0).limit(1).take
      get_next_uniform_order if invalid_uniform_order
      @next_uniform_order &&= get_next_path
    end

    def invalid_uniform_order
      false
    end

    def get_next_path
      admin_uniform_order_path(@next_uniform_order.id + 1000,
        direct_print: 1,
        pp: :disable,
        sport: params[:sport].presence,
        sent_date: params[:sent_date].presence,
        packing_slip: packing_slip ? 1 : 0
      )
    end

    def packing_slip
      @packing_slip = Boolean.strict_parse(params[:packing_slip])
    end
  end
end
