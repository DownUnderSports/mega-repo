# encoding: utf-8
# frozen_string_literal: true

module Admin
  class LegalFormsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      u = authorize User.get(params[:user_id])
      raise "User Not Found" unless u
      status = u.legal_docs_status
      return render json: {
        status: status || 'Not Submitted',
        under_age: (u.passport&.birth_date || u.birth_date || Date.today) > 18.years.ago,
        link: status \
          && url_for(u.signed_terms.attached? ? u.signed_terms : u.user_signed_terms)
      }
    end

    def create
      u = User.get(params[:user_id])

      raise "User Not Found" unless u

      raise "Document Already Submitted" if u.signed_terms.attached?

      file = begin
        params.require(:user).permit(:signed_terms)
      rescue
        nil
      end

      if file
        u.update!(file)
      else
        file = params.require(:upload).permit(:file)[:file]

        raise "File not submitted" unless file&.is_a?(ActionDispatch::Http::UploadedFile)

        u.signed_terms.attach(file)
      end

      u.reload.signed_terms.reload

      raise "Invalid File Type" unless u.signed_terms.attached?

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

      raise "Document Not Submitted" unless u.user_signed_terms.attached?

      u.user_signed_terms.purge

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
