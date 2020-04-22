# encoding: utf-8
# frozen_string_literal: true

module Admin
  class AssignmentOfBenefitsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      u = authorize User.get(params[:user_id])
      raise "User Not Found" unless u
      status = u.benefits_status
      return render json: {
        status: status || 'Not Submitted',
        link: status \
          && url_for(u.assignment_of_benefits.attached? ? u.assignment_of_benefits : u.user_assignment_of_benefits)
      }
    end

    def create
      u = User.get(params[:user_id])

      raise "User Not Found" unless u

      raise "Document Already Submitted" if u.assignment_of_benefits.attached?

      file = begin
        params.require(:user).permit(:assignment_of_benefits)
      rescue
        nil
      end

      if file
        u.update!(file)
      else
        file = params.require(:upload).permit(:file)[:file]

        raise "File not submitted" unless file&.is_a?(ActionDispatch::Http::UploadedFile)

        u.assignment_of_benefits.attach(file)
      end

      u.reload.assignment_of_benefits.reload

      raise "Invalid File Type" unless u.assignment_of_benefits.attached?

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

      raise "Document Not Submitted" unless u.user_assignment_of_benefits.attached?

      u.user_assignment_of_benefits.purge

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
