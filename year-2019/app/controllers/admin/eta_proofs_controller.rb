# encoding: utf-8
# frozen_string_literal: true

module Admin
  class EtaProofsController < Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      pp = get_passport

      return render json: {
        user_name: "#{pp.given_names} #{pp.surname} (#{pp.user.dus_id})",
        status: pp.extra_eta_processing ? 'Extra Processing Needed' : (pp.eta_proofs.attached? ? 'Completed' : 'Not Submitted'),
        can_delete: current_user&.staff&.admin?,
        proofs: pp.eta_proofs.map do |proof|
          {
            id: proof.id,
            link: url_for(proof),
          }
        end
      }
    end

    def extra
      return create
    end

    def create
      return render json: {
        errors: [ "CANNOT CREATE NEW ETAS FOR PREVIOUS YEARS" ]
      }, status: 500
    end

    def destroy
      return create
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def get_passport(*args)
        u = authorize User.get(params[:user_id]), *args

        raise "User Not Found" unless u

        pp = u.passport

        raise "Passport Not Submitted" unless pp

        pp
      end


  end
end
