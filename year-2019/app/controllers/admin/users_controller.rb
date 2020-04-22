# encoding: utf-8
# frozen_string_literal: true

module Admin
  class UsersController < Admin::ApplicationController
    # == Modules ============================================================
    include Filterable

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================
    before_action :lookup_user, except: [ :index, :infokits, :invites, :responds, :download, :cancel ]

    # == Actions ============================================================
    def index
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          filter, options = filter_records do |position|
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

          headers["X-Accel-Buffering"] = 'no'

          expires_now
          headers["Content-Type"] = "application/json; charset=utf-8"
          headers["Content-Disposition"] = 'inline'
          headers["Content-Encoding"] = 'deflate'
          headers["Last-Modified"] = Time.zone.now.ctime.to_s

          self.response_body = Enumerator.new do |y|
            deflator = StreamJSONDeflator.new(y)

            deflator.stream false, :total, base_users.count
            deflator.stream true,  :users, '['

            i = 0
            users.each do |u|
              main_user_category = u.main_relation(skip_staff: true)&.category
              deflator.stream (i += 1) > 1, nil, {
                cancel_date: u.cancel_date,
                category_id: u.category_id,
                category_type: u.category_title,
                contactable: (u.interest_id < no_interest),
                departing_date: u.departing_date,
                dus_id: u.dus_id,
                email: u.email,
                first: u.first,
                gender: u.gender,
                id: u.id,
                joined_at: u.joined_at&.in_time_zone&.to_date,
                last: u.last,
                middle: u.middle,
                phone: u.phone,
                state_abbr: u.state_abbr,
                sport_abbr: u.sport_abbr,
                suffix: u.suffix,
                traveling: u.traveler_id.present?,
                wrong_school: !!main_user_category&.wrong_school?
              }
            end

            deflator.stream false, nil, "]"

            deflator.close
          end
        end
        format.csv do
          render  csv: "all_travelers",
                  filename: "all_travelers",
                  with_time: true
        end
      end
    end

    def show
      respond_to do |format|
        format.html { fallback_index_html }
        format.json do
          if stale? @found_user
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
              deflator.stream true,  :avatar, @found_user.avatar.attached? ? url_for(@found_user.avatar.variant(resize: '500x500>')) : '/mstile-310x310.png'
              deflator.stream true,  :dus_id, @found_user.dus_id
              deflator.stream true,  :statement_link, @found_user.statement_link
              deflator.stream true,  :over_payment_link, @found_user.over_payment_link
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
              deflator.stream true,  :print_first_names, @found_user.print_first_names
              deflator.stream true,  :print_other_names, @found_user.print_other_names
              deflator.stream true,  :nick_name, @found_user.nick_name
              deflator.stream true,  :gender, @found_user.gender
              deflator.stream true,  :phone, @found_user.phone
              deflator.stream true,  :ambassador_phones, @found_user.ambassador_phone_array - [ @found_user.phone ]
              deflator.stream true,  :shirt_size, @found_user.shirt_size
              deflator.stream true,  :birth_date, @found_user.birth_date&.to_s
              deflator.stream true,  :can_text, !!@found_user.can_text
              deflator.stream true,  :address_attributes, @found_user.address&.attributes.to_h.null_to_str
              deflator.stream true,  :override_attributes, @found_user.override&.attributes.to_h.null_to_str
              deflator.stream true,  :address, @found_user.address&.to_s(:inline) || 'No Address'
              deflator.stream true,  :has_infokit, @found_user.has_infokit?
              deflator.stream true,  :interest_id, @found_user.interest_id
              deflator.stream true,  :interest_level, Interest.level(@found_user.interest_id)
              deflator.stream true,  :contactable, Interest.contactable(@found_user.interest_id)
              deflator.stream true,  :traveler, (t = @found_user.traveler)
              deflator.stream true,  :ground_only, !!t&.ground_only?
              deflator.stream true,  :total_payments, t&.total_payments&.to_i
              deflator.stream true,  :join_date, t&.join_date&.to_s
              deflator.stream true,  :team, @found_user.team || {}
              deflator.stream true,  :wrong_school, @found_user.wrong_school?
              deflator.stream true,  :staff_page, @found_user.is_staff? || @found_user.is_staff_supporter?
              if t
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
                deflator.stream true,  :coach, "{"
                deflator.stream false, :school_name, "#{(sch = @found_user.coach.school).name} (#{sch.address&.city || 'N/A'})"
                deflator.stream true,  :deposits, @found_user.coach.deposits
                deflator.stream true,  :checked_background, @found_user.coach.checked_background
                deflator.stream false, nil, "}"
              elsif @found_user.is_official?
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

    def main_address
      return render json: {
        address: (@found_user.main_address&.to_shipping || {}).merge({
          name: @found_user.full_name,
          phone: @found_user.main_phone,
          email: @found_user.main_email
        })
      }, status: 200
    end

    def infokit
      successful, errors = nil
      begin
        if has_ik = @found_user.has_infokit?
          raise :infokit_already_sent unless Boolean.parse(params[:force])
        end

        unless u = @found_user.related_athlete
          raise :not_connected_to_an_athlete
        end

        unless has_ik
          addr = @found_user.address ||
            u.address ||
            u.guardians.where_exists(:address).limit(1).take&.address ||
            u.backup_guardians.where_exists(:address).limit(1).take&.address ||
            u.related_users.where_exists(:address).limit(1).take&.address

          u.mailings.create!(
            category: :infokit,
            is_home: !!addr,
            address:  addr || u.athlete.school.address
          )
        end

        # ik_message = [ 'Sent Infokit Email' ]
        ik_message = [ 'Sent Infokit Email', "Sent Infokit Email for #{u.team&.sport&.abbr}" ]
        ik_message << 'Sent Kit Followup Email' if has_ik

        User.where(id: [
          @found_user.id,
          (u.contact_histories.where(message: ik_message).limit(1).take ? nil : u)&.id,
          *u.related_users.where.not(email: nil).
          where_not_exists(:contact_histories, message: ik_message).
          pluck(:id)
        ]).each do |ur|
          InfokitMailer.__send__(
            (has_ik ? :send_followup_details : :send_infokit),
            u.category_id, ur.ambassador_email, ur.dus_id, true
          ).deliver_later if ur&.ambassador_email.present?
        end

        successful = true
      rescue
        successful = false
        errors = $!.message
        puts $!.backtrace
      end

      return successful ? render_success : not_authorized(errors, 422)
    end

    def update
      return not_authorized("CANNOT CHANGE USERS IN PREVIOUS YEARS", 422)
    end

    def cancel
      return not_authorized("CANNOT CHANGE USERS IN PREVIOUS YEARS", 422)
    end

    def test_departure_checklist
      test_user.reset_departure_checklist
      redirect_to test_user.checklist_url
    rescue
      redirect_to test_user.checklist_url
    end

    def infokits
      csv_headers("infokits")

      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        deflator.stream Mailing::Infokit.headers

        Mailing::Infokit.csv_rows({date: params[:date].to_s}) do |row|
          deflator.stream row if row.present? && row[0].present?
        end

        deflator.close
      end
    end

    def invites
      csv_headers("invites-#{Date.parse(params[:start]).to_s}_#{Date.parse(params[:end] || params[:start]).to_s}")

      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        deflator.stream Invite.headers

        Invite.csv_rows(params) do |row, id|
          deflator.stream row unless id
        end

        deflator.close
      end
    end

    def responds
      csv_headers("responds")

      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        download_responds(deflator)

        deflator.close
      end
    end

    def download
      csv_headers("users")

      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        download_users(deflator)

        deflator.close
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

      def download_responds(csv)
        csv.stream %w[
          dus_id
          contactable
          interest_level
          respond_date
          meeting_date
          meeting_attended
          deposit_date
          cancel_date
          title
          first
          middle
          last
          suffix
          email
          phone
          guardian_relationship
          guardian_title
          guardian_first
          guardian_middle
          guardian_last
          guardian_suffix
          guardian_email
          guardian_phone
          address_is_foreign
          address_street
          address_street_2
          address_street_3
          address_city
          address_state_or_province
          address_zip
          address_country
          state
          sport
          grad
          main_event
          main_event_best
          stats
        ]

        User.order(:first, :middle, :last, :dus_id).
        where(category_type: 'athletes').
        where_exists(:mailings, category: :infokit).split_batches do |b|
          b.each do |u|
            rel = u.relations.find_by(relationship: %w[ parent guardian grandparent ])
            g = rel&.related_user
            mtg = u.meeting_registrations.joins(:meeting).references(:meeting).order('meetings.start_time').last
            addr = u.address || (g&.address)
            ath = u.athlete
            sch = ath.school
            asport = ath.athletes_sports.first

            csv.stream [
              u.dus_id,
              (u.interest_id < no_interest),
              interest_levels[u.interest_id],
              u.respond_date&.to_date,
              mtg&.meeting&.start_time&.to_date,
              mtg&.duration,
              u.traveler&.items&.first&.created_at&.to_date,
              u.traveler&.cancel_date.presence,
              u.title,
              u.first,
              u.middle,
              u.last,
              u.suffix,
              u.ambassador_email,
              u.ambassador_phone,
              rel&.relationship,
              g&.title,
              g&.first,
              g&.middle,
              g&.last,
              g&.suffix,
              g&.ambassador_email,
              g&.ambassador_phone,
              addr&.is_foreign&.to_s,
              addr&.street,
              addr&.street_2,
              addr&.street_3,
              addr&.city,
              addr&.province || addr&.state&.abbr,
              addr&.zip,
              addr&.country,
              sch.address.state.abbr,
              (ath.sport || asport&.sport)&.abbr_gender,
              ath.grad,
              asport&.main_event,
              asport&.main_event_best,
              asport&.stats,
            ]
          end
        end
      end

      def download_users(csv)
        csv.stream %w[
          dus_id
          transfer_id
          source
          title
          first
          middle
          last
          suffix
          gender
          sport_abbr
          contactable
          school_name
          original_school_name
          is_school
          street
          street_2
          street_3
          city
          state_abbr
          province
          zip
          country
          verified
          school_pid
          txfr_school_id
          invited_date
          main_event_best
          main_event
          rank
          stats
        ]

        schools = {}
        addresses = {}
        states = {}
        sources = {}
        sports = {}

        State.all.map do |st|
          states[st.id] = st.abbr
        end

        Sport.all.map do |sp|
          sports[sp.id] = sp.abbr
        end

        users = User.visible

        if Boolean.parse(params[:athletes] || params[:invited_date])
          users = User.where(category_type: 'athletes')
          if params[:invited_date].present?
            users = users.where_exists(:mailings, "category ilike 'invite%' AND sent = ?", Date.parse(params[:invited_date].to_s).to_s)
          end
        end

        users.split_batches do |b|
          b.each do |u|
            is_school = false
            athlete = u.is_athlete? ? u.athlete : nil
            source = nil
            asport = nil
            school = nil

            if athlete
              source = (sources[athlete.source_id] ||= athlete.source.name)
              asport = (athlete.athletes_sports.find_by(sport_id: athlete.sport_id) || athlete.athletes_sports.order(:created_at).first)
              school = (schools[athlete.school_id] ||= athlete.school)
            end

            addr = (
              u.address_id ? (addresses[u.address_id] ||= u.address) : nil
            ) || (
              (ru = u.related_users.where.not(address_id: nil).first) &&
              (addresses[ru.address_id] ||= ru.address)
            ) || (
              school ?
              ((is_school = true) && (addresses[school.address_id] ||= school.address)) :
              nil
            )

            csv.stream [
              u.dus_id,
              u.transfer_id,
              source,
              u.title,
              u.first,
              u.middle,
              u.last,
              u.suffix,
              u.gender,
              sports[athlete&.sport_id],
              u.contactable,
              school&.name,
              athlete&.original_school_name,
              is_school.to_s,
              addr&.street,
              addr&.street_2,
              addr&.street_3,
              addr&.city,
              states[addr&.state_id],
              addr&.province,
              addr&.zip,
              addr&.country,
              addr&.verified&.to_s,
              school&.pid,
              athlete&.txfr_school_id,
              (params[:invited_date].presence || u.mailings.invites.limit(1).take&.sent),
              asport&.main_event_best,
              asport&.main_event,
              asport&.rank,
              asport&.stats
            ]
          end
        end
      end

      def whitelisted_filter_params
        params.permit(allowed_keys)
      end

      def allowed_keys
        @allowed_keys ||= [
          :cancel_date,
          :cancels,
          :category_type,
          :departing_date,
          :dus_id,
          :email,
          :first,
          :gender,
          :joined_at,
          :last,
          :middle,
          :phone,
          :sport_abbr,
          :state_abbr,
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
