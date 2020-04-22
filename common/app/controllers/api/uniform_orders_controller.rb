# encoding: utf-8
# frozen_string_literal: true

module API
  class UniformOrdersController < API::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      u = User.find_by_dus_id_hash(params[:id])
      return head 404 unless u&.team && (u.gender != 'U')
      return render json: {
        gender: u.gender,
        orders: u.uniform_orders.count,
        sport: u.team.sport,
        state: u.team.state,
        name: u.print_names,
        dus_id: u.dus_id
      }, status: 200
    end

    def update
      u = User.find_by_dus_id_hash(params[:id])
      raise "User Not Found" unless u

      values = whitelisted_uniform_params.to_h.deep_symbolize_keys

      sport = Sport[values[:sport_id]]

      raise "Invalid Sport" unless sport

      raise "Order Already Submitted" if u.uniform_orders.find_by(sport_id: sport.id)

      if (values[:jersey_size].to_s =~ /^([A-Z]-)?\d?[A-Z]+$/) &&
        (
          values[:shorts_size].to_s =~ /^([A-Z]-)?\d?[A-Z]+$/ ||
          sport.abbr == 'GF'
        ) &&
        values[:shipping].present? &&
        values[:shipping][:name].present? &&
        values[:shipping][:street_1].present? &&
        values[:shipping][:city].present? &&
        values[:shipping][:state_abbr].present? &&
        values[:shipping][:zip].present?

        u.uniform_orders.create!(**values, submitter_id: u.id)
      else
        raise "Invalid Submission"
      end

      return render json: {}, status: 200
    rescue
      return render json: {
        errors: [ $!.message ]
      }, status: 500
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def whitelisted_uniform_params
        params.
          require(:uniform_order).
          permit(
            :sport_id,
            :jersey_size,
            :shorts_size,
            :preferred_number_1,
            :preferred_number_2,
            :preferred_number_3,
            shipping: [
              :name,
              :street_1,
              :street_2,
              :street_3,
              :city,
              :state_abbr,
              :zip,
              :country
            ]
          )
      end

  end
end
