# encoding: utf-8
# frozen_string_literal: true

module Admin
  class EtaProofsController < ::Admin::ApplicationController
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
      pp = get_passport :extra_processing?
      pp.update!(extra_eta_processing: request.method != 'DELETE')
      return render json: {
        message: 'Set Passport ETA Processing Status'
      }, status: 200
    rescue Exception
      return render json: {
        errors: [ $!.message ]
      }, status: 500
    end

    def create
      pp = get_passport

      size = pp.eta_proofs.size

      files = begin
        params.require(:user).permit(eta_proofs: [])
      rescue
        nil
      end

      if files
        pp.update!(files)
      else
        files = params.require(:upload).permit(:files)

        files.each do |file|
          raise "File not submitted" unless file&.is_a?(ActionDispatch::Http::UploadedFile)
        end

        pp.eta_proofs.attach(files)
      end

      pp.reload.eta_proofs.reload

      raise "Invalid File Type" unless pp.eta_proofs.size > size

      pp.touch

      return render json: {
        message: 'File Uploaded'
      }, status: 200
    rescue Exception
      return render json: {
        errors: [ $!.message ]
      }, status: 500
    end

    def destroy
      pp = get_passport(:admin?)
      
      raise "ETA Proof Not Found" unless proof = pp&.eta_proofs&.find(params[:id])

      proof.purge

      return render json: { message: "Deleted ETA Proof for #{pp.given_names} #{pp.surname} (#{pp.user.dus_id})" }, status: 200
    rescue
      puts $!.message
      puts $!.backtrace
      return render json: { errors: [ $!.message ] }, status: 422
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
