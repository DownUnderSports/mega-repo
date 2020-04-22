# encoding: utf-8
# frozen_string_literal: true

module API
  class DepartureChecklistsController < API::ApplicationController
    # == Modules ============================================================
    include Passportable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def show
      user = find_by_dus_id_hash
      return head 404 unless user&.team
      if stale? user
        return render json: {
          verified: user.is_verified?,
          visa_questions_answered: !!user.passport || user.travel_preparation&.has_all_questions_answered?,
          athlete: user.is_athlete?,
          coach: user.is_coach?,
          official: user.is_official?,
          legal: user.legal_docs_status,
          uniform_order: !is_active_year? || (user.team.sport.abbr === 'CH') || (user.uniform_orders.count > 0),
          passport: !!(user.passport&.has_all_questions_answered?),
          has_passport: !!(user.passport),
          registered: !is_active_year? || user.has_event_registration?,
          under_age: user.birth_date.present? ? user.under_age? : nil,
          sport: user.team.sport,
          state: user.team.state,
          name: user.print_names,
          dus_id: user.dus_id
        }, status: 200
      end
    end

    def registration
      u = find_by_dus_id_hash
      raise "User Not Found" unless u

      raise "User is Not an Athlete" unless u.is_athlete?

      values = params.require(:registration).permit(:sport_id, :handicap, :handicap_category, :height, :weight, :years_played, positions_array: [])

      raise "Sport Not Found" unless sport = u.athlete&.athletes_sports&.find_by(sport_id: values[:sport_id])

      sport.update!(values.to_h.deep_symbolize_keys.except(:sport_id).merge(submitted_info: true))

      return render json: {}, status: 200
    rescue
      return render json: {
        errors: [ $!.message ]
      }, status: 500
    end

    def get_passport
      u = find_by_dus_id_hash
      raise "User Not Found" unless u
      if !u.passport || stale?(u.passport)
        return render json: (u.passport || {}).
          as_json.
          merge(
            has_questions_answered: !!(u.passport&.has_questions_answered?),
            needs_image: !(u.passport&.image&.attached?),
          )
      end
    rescue
      puts $!.message
      puts $!.backtrace
      return render json: { errors: [ $!.message ] }, status: 422
    end

    def submit_passport
      u = find_by_dus_id_hash
      raise "User Not Found" unless u
      pp = u.passport || u.create_passport
      if !pp.image.attached?
        if(whitelisted_direct_passport_params)
          pp.update!(whitelisted_direct_passport_params.merge(checker_id: nil, second_checker_id: nil))
        else
          file = whitelisted_passport_upload_params
          if file[:io].present?
            # puts file[:io] = file[:io].to_io
            # puts file[:io].rewind
            pp.image.attach(file[:io])
            raise "Failed to attach" unless pp.image.attached?
            pp.update!(checker_id: nil, second_checker_id: nil)
          end
        end
        pp.update!(whitelisted_passport_params)
      else
        pp.update!(whitelisted_passport_visa_params)
      end
      return render json: { message: 'ok' }, status: 200
    rescue
      puts $!.message
      puts $!.backtrace
      return render json: { errors: [ $!.message ] }, status: 422
    end

    def upload_legal_form
      ClearInvalidUploadsJob.perform_later

      u = find_by_dus_id_hash

      raise "User Not Found" unless u

      u.user_signed_terms.purge if u.user_signed_terms.attached?

      file = begin
        params.require(:user).permit(:user_signed_terms)
      rescue
        nil
      end

      if file
        u.update!(file)
      else
        file = params.require(:upload).permit(:file)[:file]

        raise "File not submitted" unless file&.is_a?(ActionDispatch::Http::UploadedFile)

        u.user_signed_terms.attach(file)
        u.touch
      end

      u.reload.user_signed_terms.reload

      raise "Invalid File Type" unless u.user_signed_terms.attached?

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

    def verify_details
      user = find_by_dus_id_hash
      raise "User Not Found" unless user

      unless user.is_verified?
        values = params.require(:user).permit(:gender, :birth_date, :shirt_size).to_h.deep_symbolize_keys

        if (values[:gender].to_s =~ /^(M|F)$/) &&
          (values[:birth_date].to_s =~ /^\d{4}-\d{2}-\d{2}$/) &&
          (values[:shirt_size].to_s =~ /^[AY]-\d?[A-Z]{1,2}$/)
          user.update!(**values, is_verified: true)
        else
          raise "Invalid Submission"
        end
      end

      user.get_or_create_travel_preparation.update! whitelisted_passport_visa_params

      return render json: { message: 'ok' }, status: 200
    rescue
      puts $!.message
      puts $!.backtrace

      return render json: {
        errors: [ $!.message ]
      }, status: 422
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def find_by_dus_id_hash(k = :id)
        User.find_by_dus_id_hash(params[k])
      end


  end
end
