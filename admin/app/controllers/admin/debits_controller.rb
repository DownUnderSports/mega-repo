# encoding: utf-8
# frozen_string_literal: true

module Admin
  class DebitsController < ::Admin::ApplicationController
    # == Modules ============================================================
    include Packageable

    # == Class Methods ======================================================
    before_action :lookup_user, except: [ :base, :index ]

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def base
      debits = authorize Traveler::BaseDebit.order(:name, :amount)
      render json: {
        base_debits: debits
      }.null_to_str, status: 200
    rescue NoMethodError
      puts $!.message
      puts $!.backtrace
      return not_authorized([
        'Not Authorized',
        $!.message
      ], 422)
    end

    def additional_sport(is_update: false)
      raise "User Not Found" unless @found_user

      whitelisted = whitelisted_debit_params.to_h.symbolize_keys

      raise "Sport Not Found" unless sport = Sport.find_by(full_gender: params[:sport])

      whitelisted[:description] = "#{sport.full_gender}\n#{whitelisted[:description].to_s.presence}".strip

      whitelisted[:amount] = whitelisted[:amount].present? ? StoreAsInt.money(whitelisted[:amount]) : Traveler::BaseDebit::AdditionalSport&.amount || 0

      debit = nil

      if is_update
        debit = authorize @found_user.traveler.debits.find(params[:id])
        debit && debit.update!(whitelisted)
      else
        debits = authorize @found_user.traveler.debits
        debit = debits.create!(**whitelisted, assigner: current_user)
      end

      return render json: debit_json(debit), status: 200
    rescue
      return not_authorized [ 'Failed to add Debit', $!.message ], 422
    end

    def airfare
      raise "User Not Found" unless @found_user

      authorized = authorize Traveler::Debit

      debit = authorized.airfare(current_user, @found_user.traveler, params[:departing], params[:returning].presence, whitelisted_debit_params[:amount].presence)

      debit.update!(created_at: whitelisted_debit_params[:created_at]) if whitelisted_debit_params[:created_at]

      return head 200
    rescue
      return not_authorized [ 'Failed to add Debit', $!.message ], 422
    end

    def insurance
      respond_to do |format|
        format.csv do
          return not_authorized("Not Logged In") unless check_user

          SendCSVJob.perform_later(
            current_user&.id,
            "admin/debits/has_insurance.csv.csvrb",
            "travelers_with_insurance",
            'Insured Travelers CSV',
            "Insured Travelers for #{current_year}"
          )

          return render_success(current_user&.email || 'it@downundersports.com')
        end
        format.any do
          begin
            raise "User Not Found" unless @found_user

            authorized = authorize Traveler::Debit

            debit = authorized.insurance(current_user, @found_user.traveler)

            debit.update!(created_at: whitelisted_debit_params[:created_at]) if whitelisted_debit_params[:created_at]

            return head 200
          rescue
            return not_authorized [ 'Failed to add Debit', $!.message ], 422
          end
        end
      end


    end

    def create
      raise "User Not Found" unless @found_user

      return airfare if(Boolean.parse(params[:airfare]))
      return insurance if(Boolean.parse(params[:insurance]))
      return additional_sport if(Boolean.parse(params[:sport]))

      debits = authorize @found_user.traveler.debits
      debit = debits.create!(**whitelisted_debit_params.to_h.symbolize_keys, assigner: current_user)
      return render json: debit_json(debit), status: 200
    rescue ActiveRecord::RecordInvalid
      return not_authorized [ 'Failed to add Debit', $!.message ], 422
    end

    def destroy
      debit = authorize Traveler::Debit.includes(:traveler, :base_debit, :assigner).find_by(id: params[:id])

      debit.destroy!
      return head 200
    rescue
      return not_authorized [ 'Failed to Remove Debit', $!.message ], 422
    end

    def update
      return airfare if(Boolean.parse(params[:airfare]))
      return insurance if(Boolean.parse(params[:insurance]))
      return additional_sport(is_update: true) if(Boolean.parse(params[:sport]))

      debit = authorize @found_user.traveler.debits.find(params[:id])
      debit && debit.update!(whitelisted_debit_params)
      return render json: debit_json(debit), status: 200
    rescue ActiveRecord::RecordInvalid
      return not_authorized [ 'Failed to add Debit', $!.message ], 422
    end

    def show
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          debit = authorize Traveler::Debit.includes(:traveler, :base_debit, :assigner).
          find_by(params[:base_debit_id].present? ? {base_debit_id: params[:base_debit_id]} : {id: params[:id]})

          render json: debit_json(debit), status: 200 if stale? debit
        end
      end
    rescue NoMethodError
      return not_authorized([
        'Debit not found',
        $!.message
      ], 422)
    end

    def index
      return show if params[:base_debit_id].present?

      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          lookup_user if params[:user_id].present?
          debits = authorize (@found_user ? @found_user.traveler.debits : Traveler::Debit).includes(:traveler, :base_debit, :assigner).order(:name, :amount)

          if stale? debits
            headers["X-Accel-Buffering"] = 'no'

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :debits, '['

              i = 0
              debits.each do |d|
                deflator.stream (i += 1) > 1, nil, debit_json(d)
              end

              deflator.stream false, nil, ']'
              deflator.close
            end
          end
        end
      end
    rescue NoMethodError
      return not_authorized([
        'Invalid',
        $!.message
      ], 422)
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

    private
      def whitelisted_debit_params
        return @whitelisted_debit_params if @whitelisted_debit_params
        @whitelisted_debit_params = all_debit_params.permit(:base_debit_id, :amount, :name, :description)
        if all_debit_params[:created_at_override].present?
          cr_time = Time.zone.parse(all_debit_params[:created_at_override]).midnight + 2.hours
          @whitelisted_debit_params[:created_at] = cr_time unless @debit && (@debit.created_at.to_date == cr_time&.to_date)
        end
        @whitelisted_debit_params
      end

      def all_debit_params
        params.require(:debit)
      end

  end
end
