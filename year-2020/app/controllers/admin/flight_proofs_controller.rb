# encoding: utf-8
# frozen_string_literal: true

module Admin
  class FlightProofsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def index
      u = authorize User.get(params[:user_id])
      raise "User Not Found" unless u
      return render json: {
        user_name: "#{u.full_name} (#{u.dus_id})",
        status: u.flight_proofs.attached? ? 'Completed' : 'Not Submitted',
        can_delete: current_user&.staff&.admin?,
        proofs: u.flight_proofs.map do |proof|
          {
            id: proof.id,
            link: url_for(proof),
          }
        end
      }
    end

    def create
      u = User.get(params[:user_id])

      raise "User Not Found" unless u

      size = u.flight_proofs.size

      files = begin
        params.require(:user).permit(flight_proofs: [])
      rescue
        nil
      end

      if files
        u.update!(files)
      else
        files = params.require(:upload).permit(:files)

        files.each do |file|
          raise "File not submitted" unless file&.is_a?(ActionDispatch::Http::UploadedFile)
        end

        u.flight_proofs.attach(files)
      end

      u.reload.flight_proofs.reload

      raise "Invalid File Type" unless u.flight_proofs.size > size

      u.touch

      return render json: {
        message: 'File Uploaded'
      }, status: 200
    rescue Exception
      return render json: {
        errors: [ $!.message ]
      }, status: 500
    end

    def destroy
      raise "Not Authorized" unless current_user.staff&.admin?

      raise "User Not Found" unless u = User.get(params[:user_id])

      raise "Flight Proof Not Found" unless proof = u.flight_proofs.find(params[:id])

      proof.purge

      return render json: { message: "Deleted Flight Proof for #{u.print_names}" }, status: 200
    rescue
      puts $!.message
      puts $!.backtrace
      return render json: { errors: [ $!.message ] }, status: 422
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
