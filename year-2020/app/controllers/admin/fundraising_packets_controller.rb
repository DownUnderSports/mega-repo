# encoding: utf-8
# frozen_string_literal: true

module Admin
  class FundraisingPacketsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      u = authorize User.get(params[:user_id])
      raise "User Not Found" unless u
      status = u.fundraising_packet_status
      return render json: {
        status: status || 'Not Uploaded',
        link: status \
          && url_for(u.fundraising_packet)
      }
    end

    def create
      u = User.get(params[:user_id])

      raise "User Not Found" unless u

      raise "Document Already Submitted" if u.fundraising_packet.attached?

      file = begin
        params.require(:user).permit(:fundraising_packet)
      rescue
        nil
      end

      if file
        u.update!(file)
      else
        file = params.require(:upload).permit(:file)[:file]

        raise "File not submitted" unless file&.is_a?(ActionDispatch::Http::UploadedFile)

        u.fundraising_packet.attach(file)
      end

      u.reload.fundraising_packet.reload

      raise "Invalid File Type" unless u.fundraising_packet.attached?

      u.touch

      return render json: {
        message: 'File Uploaded'
      }, status: 200
    rescue Exception
      p $!.message
      p $!.backtrace
      return render json: {
        errors: [ $!.message ]
      }, status: 500
    end

    def destroy
      u = User.get(params[:user_id])

      raise "User Not Found" unless u

      raise "Document Not Submitted" unless u.fundraising_packet.attached?

      u.fundraising_packet.purge

      u.touch

      return render json: {
        message: 'File Destroyed'
      }, status: 200
    rescue Exception
      p $!.message
      p $!.backtrace
      return render json: {
        errors: [ $!.message ]
      }, status: 500
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
