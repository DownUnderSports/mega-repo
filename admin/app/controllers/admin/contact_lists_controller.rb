# encoding: utf-8
# frozen_string_literal: true

module Admin
  class ContactListsController < ::Admin::ApplicationController
    # == Modules ============================================================

    # == Class Methods ======================================================

    # == Pre/Post Flight Checks =============================================

    # == Actions ============================================================
    def school_addresses
      return render csv: 'school_addresses'
    end

    def new_year_student_lists
      csv_headers("student_list_resend_#{Date.today.year}")

      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        deflator.stream %w[
          athlete_id
          grad
          first
          last
          school_name
          school_city
          school_state
          school_zip
          sent
        ]

        User.
          athletes.
          where(responded_at: nil).
          where_exists(:address).
          update_all(address_id: nil)

        User.athletes.where_not_exists(:address).split_batches_values do |user|
          next unless user.interest.contactable_next_year? && user&.athlete&.school&.address

          next if user.athlete.grad.present? && (
              user.athlete.grad <
                (Date.today.year + ((Date.today.month < 8) ? 0 : 1))
            )

          deflator.stream [
            user.id,
            user.athlete.grad,
            user.first,
            user.last,
            user.athlete.school.name,
            user.athlete.school.address.city,
            user.athlete.school.address.state&.abbr,
            user.athlete.school.address.zip,
            Date.today.to_s
          ]
        end

        deflator.close
      end
    end

    def jersey_numbers_by_team
      csv_headers("jersey_numbers-#{params[:sport_id]}")
      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        deflator.stream %w[
          id
          competing_team
          jersey_number
          preferred_number_1
          preferred_number_2
          preferred_number_3
          url
        ]

        sport_id = Sport[params[:sport_id]]&.id

        errors = User::UniformOrder.assign_numbers(sport_id)

        User::UniformOrder.where(sport_id: sport_id, is_reorder: false).order(:id).each do |uo|
          deflator.stream [
            uo.id,
            uo.user&.traveler&.competing_teams&.find_by(sport_id: uo.sport_id)&.letter,
            uo.jersey_number,
            *(
              uo.submitted_to_shop_at.present? ?
                Array.new(3) :
                [
                  uo.preferred_number_1,
                  uo.preferred_number_2,
                  uo.preferred_number_3,
                ]
            ),
            uo.user&.admin_url
          ]
        end

        if errors.present?
          deflator.stream Array.new(7)

          deflator.stream [
            *Array.new(6),
            '######### ERRORS/DETAILS #########',
          ]

          (errors || []).each do |err|
            deflator.stream [
              *Array.new(6),
              err,
            ]
          end
        end

        deflator.close
      end
    end

    def missing_uniforms
      csv_headers("missing_uniforms-#{params[:sport_id]}")
      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        deflator.stream %w[
          departing_date
          state
          sport
          emails
          phones
          admin_url
          uniform_order_url
        ]

        missing = User::UniformOrder.find_missing(params[:sport_id])

        missing.in_groups_of(8).each do |g|
          deflator.stream g[0...-1]
        end

        deflator.close
      end
    end

    def missing_legal_docs
      csv_headers("missing_legal_docs")

      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        deflator.stream %w[
          status
          category
          departing_date
          state
          sport
          emails
          phones
          admin_url
          registration_url
        ]

        Traveler.active do |t|
          next if t.team.state.in? [ State::ST, State::AUS ]

          deflator.stream [
            t.user.legal_docs_status || 'Not Submitted',
            t.user.category_title,
            t.departing_date,
            t.team.state.abbr,
            t.team.sport.abbr_gender,
            t.user.athlete_and_parent_emails.join(';'),
            t.user.athlete_and_parent_phones.join(';'),
            t.user.admin_url,
            t.user.checklist_url,
          ]
        end

        deflator.close
      end
    end

    def missing_event_reg
      csv_headers("missing_event_reg")

      self.response_body = Enumerator.new do |y|
        deflator = StreamCSVDeflator.new(y)

        deflator.stream %w[
          sport
          departing_date
          admin_url
          checklist_url
        ]

        Traveler.active do |t|
          t.user.missing_event_registrations.each do |sport|
            deflator.stream [
              sport.abbr_gender,
              t.departing_date,
              t.user.admin_url,
              "#{t.user.hash_url('event-registration')}/#{sport.abbr_gender}"
            ]
          end
        end

        deflator.close
      end
    end

    def fb_travelers
      @travelers = Traveler.
          active.
          joins(
            <<-SQL.gsub(/\s*\n?\s+/m, ' ')
              INNER JOIN teams
                ON teams.id = travelers.team_id
              INNER JOIN users
                ON users.id = travelers.user_id
              INNER JOIN athletes
                ON (
                  (users.category_type = 'athletes')
                  AND
                  (athletes.id = users.category_id)
                )
              LEFT JOIN athletes_sports
                ON (
                  (athletes_sports.athlete_id = athletes.id)
                  AND
                  (athletes_sports.sport_id = teams.sport_id)
                )
              LEFT JOIN schools
                ON schools.id = athletes.school_id
              LEFT JOIN addresses school_addresses
                ON school_addresses.id = schools.address_id
              LEFT JOIN states school_states
                ON school_states.id = COALESCE(school_addresses.state_id, teams.state_id)
              LEFT JOIN (
                SELECT
                  traveler_id,
                  MIN(created_at) AS created_at,
                  SUM(amount) AS amount
                FROM payment_items
                WHERE traveler_id IS NOT NULL
                GROUP BY traveler_id
              ) payment_summaries
              ON payment_summaries.traveler_id = travelers.id
            SQL
          ).
          where(teams: { sport_id: Sport::FB.id } ).
          order("school_states.abbr", "payment_summaries.amount").
          select(
            %Q(
              travelers.*,
              users.dus_id,
              users.first,
              users.last,
              athletes.grad,
              schools.name AS school_name,
              school_addresses.city AS school_city,
              school_states.abbr AS school_state_abbr,
              teams.name AS team_name,
              athletes_sports.positions_array,
              athletes_sports.height,
              athletes_sports.weight,
              athletes_sports.stats,
              COALESCE(payment_summaries.created_at, travelers.created_at) AS joined_at,
              payment_summaries.amount AS current_payments
            )
          )


      respond_to do |format|
        format.pdf { render pdf: "fb_travelers_list_#{Time.now.to_s(:db).gsub(/\s/, '_')}", show_as_html: true }
        format.csv do
          render csv: "fb_travelers", filename: "fb_travelers_list", with_time: true
        end
      end
    end

    def dbag_mailings
      respond_to do |format|
        format.csv do
          render csv: "dbag_mailings", filename: "dbag_mailings", with_time: true
        end
      end
    end

    def bonus_travel_packet_mailings
      respond_to do |format|
        format.csv do
          render csv: "bonus_travel_packet_mailings", filename: "bonus_travel_packet_mailings", with_time: true
        end
      end
    end

    def gbr_letter
      respond_to do |format|
        format.csv do
          render csv: "gbr_letter", filename: "gbr_free_offer", with_time: true
        end
      end
    end

    def gbr_travelers
      respond_to do |format|
        format.csv do
          render csv: "gbr_travelers", filename: "gbr_travelers_list", with_time: true
        end
      end
    end

    def mtg_postcard
      respond_to do |format|
        format.csv do
          render csv: "mtg_postcard", filename: "mtg_postcard", with_time: true
        end
      end
    end

    def sport_travelers
      respond_to do |format|
        format.csv do
          sport_param = params[:sport].presence
          @sport = sport_param \
            ? Sport.
              where(abbr: sport_param).
              or(Sport.where(abbr_gender: sport_param)) \
            : Sport.all

          render csv: "sport_travelers",
                with_time: true,
                filename: "#{
                            sport_param ? 'active_' : 'all_active'
                          }#{
                            sport_param \
                              ? @sport.take.
                                  __send__(
                                    @sport.size > 1 ? :full : :full_gender
                                  ).
                                  downcase.
                                  gsub(/\s+/, '_') \
                              : ''
                          }_travelers"
        end
      end
    end

    # == Cleanup ============================================================

    # == Utilities ==========================================================

  end
end
