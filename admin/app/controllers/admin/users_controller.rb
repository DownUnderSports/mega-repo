# encoding: utf-8
# frozen_string_literal: true

module Admin
  class UsersController < ::Admin::ApplicationController
    # == Modules ============================================================
    include Filterable

    IDBuilder = Struct.new(:id)

    # == Class Methods ======================================================
    FENCEABLE_USERS = %[ DAN-IEL GAY-LEO SAR-ALO SAM-PSN ].freeze
    CORONABLE_USERS = %[ DAN-IEL GAY-LEO SAR-ALO SAM-PSN SHR-RIE KAR-ENJ ].freeze

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [ :cancel, :download, :index, :infokits, :invitable, :invites, :responds, :uncontacted_last_year_responds ]

    # == Actions ============================================================
    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          filter, options = filter_records(boolean_regex: /deferral/) do |position|
            position.after do |prefix, param, value, options, not_like, separator|
              case true
              when !!((param.to_s =~ /category/) && (value.to_s =~ /supporter/i))
                options[:filter] << "#{separator}(category_type IS NULL)"
                options
              when !!(param.to_s =~ /travelers|cancels/)
                options[:filter] << "#{separator}(traveler_id IS NOT NULL) AND (cancel_date IS#{(param.to_s =~ /^c/) ? ' NOT' : ''} NULL)"
                options
              when !!(param.to_s =~ /wrong_school/)
                options[:filter] << "#{separator}(school_id = :#{prefix}wrong_school_id)"
                options["#{prefix}wrong_school_id"] = wrong_school&.id
                options
              else
                false
              end
            end
          end

          base_users = User::Views::Index.all

          base_users =
            authorize filter ?
              base_users.where(filter, options.deep_symbolize_keys) :
              base_users

          users = base_users.order(*get_sort_params).offset((params[:page] || 0).to_i * 100).limit(100)

          json_headers

          self.response_body = Enumerator.new do |y|
            deflator = StreamJSONDeflator.new(y)

            deflator.stream false, :total, base_users.count
            deflator.stream true,  :users, '['

            i = 0
            users.each do |u|
              main_user_category = u.main_relation(skip_staff: true)&.category
              deflator.stream (i += 1) > 1, nil, {
                can_compete: (u.can_compete rescue nil),
                can_transfer: (u.can_transfer rescue nil),
                cancel_date: u.cancel_date,
                category_id: u.category_id,
                category_type: u.category_title,
                certifiable: !!u.certifiable,
                contactable: (u.interest_id < no_interest),
                deferral: !!u.deferral,
                departing_date: u.departing_date,
                difficulty: (u.difficulty rescue nil),
                dus_id: u.dus_id,
                email: u.email,
                first: u.first,
                gender: u.gender,
                grad: u.grad,
                id: u.id,
                invitable: !!u.invitable,
                joined_at: u.joined_at&.in_time_zone&.to_date,
                last: u.last,
                max_grad_year: u.max_grad_year,
                middle: u.middle,
                phone: u.phone,
                sport_abbr: u.sport_abbr,
                sr_only: u.is_athlete? && u.max_grad_year && (u.grad.blank? || (u.grad > u.max_grad_year)),
                state_abbr: u.state_abbr,
                status: (u.status rescue nil),
                suffix: u.suffix,
                traveling: u.traveler_id.present?,
                wrong_school: !!main_user_category&.wrong_school?,
              }
            end

            deflator.stream false, nil, "]"

            deflator.close
          end
        end
        format.csv do
          return not_authorized("Not Logged In") unless check_user

          if Boolean.parse(params[:textline])
            SendCSVJob.perform_later(
              current_user&.id,
              "admin/users/textline.csv.csvrb",
              "textline_import_sheet",
              'Upload to Textline CSV',
              "Update Textline Contacts"
            )
          elsif Boolean.parse(params[:travelex])
            SendCSVJob.perform_later(
              current_user&.id,
              "admin/users/travelex_totals.csv.csvrb",
              "travelex_totals",
              'Insurance paid, not canceled before March 20th CSV',
              'Insurance paid, not canceled before March 20th CSV'
            )
          else
            SendCSVJob.perform_later(
              current_user&.id,
              "admin/users/all_travelers.csv.csvrb",
              "all_travelers",
              'All Travelers CSV',
              "All Travelers for #{current_year}"
            )
          end

          return render_success(current_user&.email || 'it@downundersports.com')
          # render  csv: "all_travelers",
          #         filename: "all_travelers",
          #         with_time: true
        end
        format.xlsx do
          return run_an_api_action do
            value = IDBuilder.new(current_user&.email || 'it@downundersports.com')

            FileMailer.
              with(
                email: value.id,
                name: 'traveler_debits',
                mime_type: 'xlsx',
                handler: 'axlsx',
                extension: 'xlsx',
                template: 'admin/users/traveler_debits',
                message: 'Here is your Traveler Debit Worksheet',
                subject: 'Traveler Debits Worksheet'
              ).
              send_file.
              deliver_later(queue: :staff_mailer)

            value
          end
        end
      end
    end

    def show
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          t_stamp = [
            Time.zone.parse('2020-02-25 17:00:00'),
            @found_user&.updated_at || Time.zone.now
          ].max

          if Boolean.parse(params[:force]) || stale?(@found_user, last_modified: t_stamp)
            headers["X-Accel-Buffering"] = 'no'
            # fresh_when(@found_user)

            expires_now
            headers["Content-Type"] = "application/json; charset=utf-8"
            headers["Content-Disposition"] = 'inline'
            headers["Content-Encoding"] = 'deflate'
            headers["Last-Modified"] = Time.zone.now.ctime.to_s

            self.response_body = Enumerator.new do |y|
              deflator = StreamJSONDeflator.new(y)

              deflator.stream false, :avatar_attached, @found_user.avatar.attached?
              deflator.stream true,  :avatar, @found_user.avatar.attached? ? url_for(@found_user.avatar.variant(resize: '500x500>', auto_orient: true)) : '/mstile-310x310.png'
              deflator.stream true,  :can_send_fence, current_user&.dus_id&.in?(FENCEABLE_USERS)
              deflator.stream true,  :can_send_corona, current_user&.dus_id&.in?(CORONABLE_USERS)
              deflator.stream true,  :dus_id, @found_user.dus_id
              deflator.stream true,  :statement_link, @found_user.statement_link
              deflator.stream true,  :over_payment_link, @found_user.over_payment_link
              deflator.stream true,  :checklist_link, @found_user.checklist_url
              deflator.stream true,  :category, @found_user.category_title
              deflator.stream true,  :category_type, @found_user.category_type
              deflator.stream true,  :category_id, @found_user.category_id
              deflator.stream true,  :email, @found_user.email
              deflator.stream true,  :ambassador_emails, @found_user.ambassador_email_array - [ @found_user.email ]
              deflator.stream true,  :title, @found_user.title
              deflator.stream true,  :first, @found_user.first
              deflator.stream true,  :middle, @found_user.middle
              deflator.stream true,  :last, @found_user.last
              deflator.stream true,  :suffix, @found_user.suffix
              deflator.stream true,  :keep_name, !!@found_user.keep_name
              deflator.stream true,  :print_first_names, @found_user.print_first_names
              deflator.stream true,  :print_other_names, @found_user.print_other_names
              deflator.stream true,  :nick_name, @found_user.nick_name
              deflator.stream true,  :gender, @found_user.gender
              deflator.stream true,  :phone, @found_user.phone
              deflator.stream true,  :ambassador_phones, @found_user.ambassador_phone_array - [ @found_user.phone ]
              deflator.stream true,  :shirt_size, @found_user.shirt_size
              deflator.stream true,  :birth_date, @found_user.birth_date&.to_s
              deflator.stream true,  :can_text, !!@found_user.can_text
              deflator.stream true,  :travel_preparation_attributes, @found_user.travel_preparation&.attributes.to_h.null_to_str
              deflator.stream true,  :address_attributes, @found_user.address&.attributes.to_h.null_to_str
              deflator.stream true,  :override_attributes, @found_user.override&.attributes.to_h.null_to_str
              deflator.stream true,  :address, @found_user.address&.to_s(:inline) || 'No Address'
              deflator.stream true,  :has_infokit, @found_user.has_infokit?
              deflator.stream true,  :interest_id, @found_user.interest_id
              deflator.stream true,  :interest_level, Interest.level(@found_user.interest_id)
              deflator.stream true,  :contactable, Interest.contactable(@found_user.interest_id)
              deflator.stream true,  :traveler, (t = @found_user.traveler)&.as_json
              deflator.stream true,  :ground_only, !!t&.ground_only?
              deflator.stream true,  :total_payments, t&.total_payments&.to_i
              deflator.stream true,  :join_date, t&.join_date&.to_s
              deflator.stream true,  :team, @found_user.team || {}
              deflator.stream true,  :invite_rule, (@found_user.invite_rule rescue {}) || {}
              deflator.stream true,  :wrong_school, @found_user.wrong_school?
              deflator.stream true,  :staff_page, @found_user.is_staff? || @found_user.is_staff_supporter?
              if t
                deflator.stream true,  :allow_travel_dates, current_user&.staff&.check(:flights)
                deflator.stream true,  :departing_date_override, @found_user.departing_date_override
                deflator.stream true,  :returning_date_override, @found_user.returning_date_override

                deflator.stream true,  :pnrs, t.flight_schedules&.map(&:pnr)
                deflator.stream true,  :buses, (
                  t.buses.map do |b|
                    b.as_json.merge(text: b.to_str)
                  end
                )
                deflator.stream true,  :final_packet_base, url_with_auth("/admin/print_packets/#{@found_user.dus_id}")
                deflator.stream true,  :competing_team_list, t.competing_teams_string.presence
              end

              if @found_user.is_athlete?
                deflator.stream true,  :is_athlete, true
                deflator.stream true,  :athlete_sport_id, @found_user.athlete.sport_id
                deflator.stream true,  :athlete_grad, @found_user.athlete.grad
                deflator.stream true,  :athlete, "{"
                deflator.stream false, :year_grad, @found_user.athlete.grad
                deflator.stream true,  :school_name, "#{(sch = @found_user.athlete.school).name} (#{sch.address.city})"
                deflator.stream true,  :source_name, @found_user.athlete.source.name
                deflator.stream true,  :sport_abbr, sport_abbr = @found_user.team&.sport&.abbr_gender || @found_user.athlete&.sport&.abbr_gender
                deflator.stream true,  :main_event, (
                  sport_info = sport_abbr.presence &&
                    @found_user.athlete&.
                      athletes_sports&.
                      find_by(sport: Sport.find_by(abbr_gender: sport_abbr))
                )&.main_event
                deflator.stream true,  :main_event_best, sport_info&.main_event_best.presence
                deflator.stream true,  :stats, sport_info&.stats
                deflator.stream true,  :invited_date, sport_info&.invited ? sport_info.invited_date.to_s : nil
                deflator.stream true,  :attributes, @found_user.athlete.attributes
                deflator.stream false, nil, "}"
                deflator.stream true,  :athletes_sports_attributes, @found_user.athletes_sports.map {|as| as.attributes.to_h.null_to_str.merge(sport_abbr: as.sport&.abbr_gender)}
              elsif @found_user.is_coach?
                deflator.stream true,  :is_coach, true
                deflator.stream true,  :checked_background, @found_user.checked_background
                deflator.stream true,  :polo_size, @found_user.polo_size
                deflator.stream true,  :coach, "{"
                deflator.stream false, :school_name, "#{(sch = @found_user.coach.school).name} (#{sch.address&.city || 'N/A'})"
                deflator.stream true,  :deposits, @found_user.coach.deposits
                deflator.stream true,  :checked_background, @found_user.coach.checked_background
                deflator.stream true,  :polo_size, @found_user.coach.polo_size
                deflator.stream false, nil, "}"
              elsif @found_user.is_official?
                deflator.stream true,  :is_official, true
                deflator.stream true,  :official, "{"
                deflator.stream false, :category, @found_user.official.category.to_s
                deflator.stream false, nil, "}"
              end

              deflator.close
            end
          end
        end
      end
    rescue NoMethodError
      return not_authorized([
        'User not found',
        $!.message
      ], 422)
    end

    def on_the_fence
      email = params[:email].presence || @found_user.athlete_and_parent_emails

      TravelMailer.
        with(email: email).
        on_the_fence.
        deliver_later

      @found_user.
        contact_histories.
        create(
          message: 'Sent "On the Fence" Email',
          category: :email,
          reason: :other,
          reviewed: true,
          staff_id: (current_user || auto_worker).category_id
        )

      return render json: { sent: email }, status: 200
    end

    def selected_cancel
      CoronaMailer.
        with(
          user_id: @found_user.id,
          email: params[:email].presence
        ).
        cancel_selected.
        deliver_later

      return render json: { sent: params[:email].presence }, status: 200
    end

    def unselected_cancel
      CoronaMailer.
        with(
          user_id: @found_user.id,
          email: params[:email].presence
        ).
        cancel_unselected.
        deliver_later

      return render json: { sent: params[:email].presence }, status: 200
    end

    def main_address
      return render json: {
        address: (@found_user.main_address&.to_shipping || {}).merge({
          name: @found_user.full_name,
          phone: @found_user.main_phone,
          email: @found_user.main_email
        })
      }, status: 200
    end

    def addresses_available
      return render json: { addresses: [] } unless @found_user || lookup_user
      addresses = []
      if @found_user.address&.unrejected
        addresses << {
          label: "#{@found_user.basic_name} (Self - Home): #{@found_user.address.inline}",
          address: @found_user.address.to_shipping.merge(is_home: true, is_foreign: !!@found_user.address.is_foreign)
        }
      end
      if @found_user.is_athlete? && (school = @found_user.athlete&.school)&.address&.unrejected
        addresses << {
          label: "#{school.name} (School): #{school.address.inline}",
          address: school.address.to_shipping.merge(is_home: false, is_foreign: !!school.address.is_foreign)
        }
      end

      @found_user.relations.each do |rel|
        user = rel.related_user
        if user.address&.unrejected
          addresses << {
            label: "#{user.basic_name} (#{rel.relationship.titleize} - Home): #{user.address.inline}",
            address: user.address.to_shipping.merge(is_home: true, is_foreign: !!user.address.is_foreign)
          }
        end
      end
      return render json: { addresses: addresses }
    rescue
      puts $!.message
      puts $!.backtrace
      return render json: { addresses: [] }
    end

    def travel_preparation
      raise "Invalid Option" unless params[:category].in?(User::TravelPreparation.milestones)
      prep = @found_user.get_or_create_travel_preparation

      if params[:category] =~ /^(call|email)ed_[a-z_]+_type$/
        value = params[:value].presence

        date = params[:value].presence ? Date.today : nil
        date_key = params[:category].to_s.sub("type", "date")
        user_key = params[:category].to_s.sub("type", "user")

        prep.update! params[:category] => value, date_key => date, user_key => current_user&.print_names
      else
        prep.update! params[:category] => Date.today
      end

    rescue
      return not_authorized([ $!.message ], 422)
    end

    def infokit
      # Kernel Method - Does Lookup
      successful, errors = infokit_mail_and_emails(@found_user)

      return successful ? render_success : not_authorized(errors, 422)
    end

    def update
      successful, errors = nil

      begin
        @found_user.stats_sport_id = whitelisted_user_params[:stats_sport_id] if(whitelisted_user_params[:stats_sport_id].present?)

        @found_user.update!(
          (!current_user&.staff&.check(:admin) && @found_user.is_dus_staff?) ?
          whitelisted_user_params.except(:email) :
          whitelisted_user_params
        )

        if whitelisted_user_params[:athlete_sport_id].present?
          @found_user.athlete_sport_id = whitelisted_user_params[:athlete_sport_id]
          @found_user.save! if @found_user.athlete_sport_id&.to_i == whitelisted_user_params[:athlete_sport_id].to_i
        end

        @found_user.traveler.save! if @found_user.traveler&.departing_date_changed? || @found_user.traveler&.returning_date_changed?

        successful = true
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    def cancel
      lookup_user
      if !@found_user&.traveler
        return render json: { error: 'Not a Traveler' }, status: 422
      elsif @found_user.traveler.cancel_date.present?
        return render json: { error: 'Already Canceled' }, status: 422
      elsif !@found_user.traveler.update(cancel_date: Date.today)
        if @found_user.is_deferral?
          send_transfer_confirmation @found_user
        else
          send_cancellation_confirmation @found_user
        end
        return render json: { error: @found_user.traveler.errors.full_messages.first }, status: 422
      else
        return render json: { success: true }, status: 200
      end
    rescue not_authorized_error
      u = User[params[:id]]
      result = send_cancellation_confirmation u
      return render json: { error: result ? 'Cancel request sent to IT' : 'Something went wrong' }, status: 422
    end

    def test_departure_checklist
      test_user.reset_departure_checklist
      redirect_to test_user.checklist_url
    rescue
      redirect_to test_user.checklist_url
    end

    def infokits
      respond_to do |format|
        format.html do
          render html:'', layout: 'internal'
        end
        format.csv do
          return not_authorized("Not Logged In") unless check_user

          SendCSVJob.perform_later(
            current_user&.id,
            "admin/users/infokits.csv.csvrb",
            "infokits",
            'Submit Infokits CSV',
            "Marked unsubmitted infokits for RRD",
            { date: params[:date].to_s }
          )

          json_headers deflate: false


          return render_success(current_user&.email || 'it@downundersports.com')
        end
      end
    end

    def invites
      respond_to do |format|
        format.html do
          render "invites", layout: 'internal'
        end
        format.csv do
          # @params = params

          SendCSVJob.perform_later(
            current_user&.id,
            "admin/users/invites.csv.csvrb",
            "invites-#{Date.parse(params[:start]).to_s}#{params[:end].present? ? "_#{Date.parse(params[:end]).to_s}" : ''}",
            'Submit Invites CSV',
            "RRD Invites for submitted date range",
            { params: params.to_unsafe_h.symbolize_keys.present_only, with_time: false }
          )

          json_headers deflate: false

          return render_success(current_user&.email || 'it@downundersports.com')

          # return render csv: 'invites',
          #               filename: ,
          #               with_time: false
        end
      end
    end

    def invitable
      @job_started = params[:started].present?

      respond_to do |format|
        format.html do
          render layout: 'internal'
        end
        format.csv do
          raise "Not Logged In" unless current_user&.is_dus_staff?

          SendInvitableJob.perform_later(current_user.id)

          redirect_to "/admin/users/invitable.html?started=1"
        end
      end
    end

    def responds
      respond_to do |format|
        format.html do
          render html:'', layout: 'internal'
        end
        format.csv do
          SendCSVJob.perform_later(
            current_user&.id,
            "admin/users/responds.csv.csvrb",
            "responds",
            'All Responds CSV',
            "All Responds in the system CSV"
          )

          # return render csv: 'responds', filename: 'responds', with_time: true

          json_headers deflate: false

          return render_success(current_user&.email || 'it@downundersports.com')
        end
      end
    end

    def uncontacted_last_year_responds
      respond_to do |format|
        format.html do
          render html:'', layout: 'internal'
        end
        format.csv do
          SendCSVJob.perform_later(
            current_user&.id,
            "admin/users/uncontacted_last_year_responds.csv.csvrb",
            "uncontacted_last_year_responds",
            'Responded Last Year, Uncontacted CSV',
            'Responded Last Year, Uncontacted CSV',
          )

          json_headers deflate: false

          return render_success(current_user&.email || 'it@downundersports.com')
        end
      end
    end

    def download
      respond_to do |format|
        format.html do
          render html:'', layout: 'internal'
        end
        format.csv do
          @invited_date = params[:invited_date].presence
          @athletes_only = Boolean.parse(params[:athletes] || @invited_date)
          return render csv: 'download', filename: 'users', with_time: true
        end
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================
    private
      def lookup_user
        unless request.format.html? && !current_token
          authorize (@found_user = User.get(params[:id]))
        end
      end

      def send_cancellation_confirmation(u)
        if u&.can_send_cancellation?
          u.send_cancellation_email
          UserMailer.with(user_id: u.id, staff_user_id: current_user.id).cancel.deliver_later(queue: :staff_mailer)
          true
        else
          false
        end
      end

      def send_transfer_confirmation(u)
        u.send_transfer_email if u&.can_send_transfer?
      end

      def whitelisted_filter_params
        params.permit(allowed_keys)
      end

      def allowed_keys
        @allowed_keys ||= [
          :can_compete,
          :can_transfer,
          :cancel_date,
          :cancels,
          :category_type,
          :certifiable,
          :deferral,
          :departing_date,
          :difficulty,
          :dus_id,
          :email,
          :first,
          :gender,
          :grad,
          :invitable,
          :joined_at,
          :last,
          :middle,
          :max_grad_year,
          :phone,
          :sport_abbr,
          :state_abbr,
          :status,
          :suffix,
          :travelers,
          :wrong_school,
        ].freeze
      end

      def default_sort_order
        %i[ first middle last suffix id ]
      end
  end
end
