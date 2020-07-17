# encoding: utf-8
# frozen_string_literal: true

require_dependency 'invite/parser'

module Invite
  class Lister < Parser
    def self.headers
      %w[ USER_ID DUS_ID WAS_MISMATCH INTEREST_LEVEL TOTAL_INVITES TOTAL_HOME TOTAL_SCHOOL ] +
      %w[ SUCCESSFUL FAILED SUCCESSFUL_HOME FAILED_HOME SUCCESSFUL_SCHOOL FAILED_SCHOOL NEXT_DATE ] +
      sport_headers +
      %w[ IS_ALUMNI IS_HOME OK_INVITE WITH_CERTIFICATE STATE SPORT GRAD FIRST LAST ] +
      %w[ SCHOOL_NAME SCHOOL_STATE SCHOOL_CITY SCHOOL_ZIP SCHOOL_ID ADDRESS_ID STATS URL ]
    end

    def self.sport_headers
      sports_list.map {|sport| "INVITED_#{sport.abbr_gender}" }
    end

    def self.sports_list
      Sport.
        order(:id).
        where.not(abbr: 'ST')
    end

    def self.csv_rows(params)
      clear_dups

      query = User::Views::Index.
        athletes_this_year.
        where(traveler_id: nil).
        where_not_exists(:messages, message: '2019 Traveler')

      ct = i = 0
      count = query.count(:all)
      first_invite_date = Mailing.invites.order(:sent).take&.sent || Date.today
      quiet_failure = Boolean.parse(params[:quiet_failure])

      query.split_batches_values(start: params[:start] || 0) do |user|
        begin
          p ct if ((ct += 1) % 1000) == 0
          r = new(user.mailings.build, first_invite_date)
          unless r.allowed
            sch = r.athlete&.school
            raise NoMethodError.new("#{i += 1} of #{count} -- NOT ALLOWED -- #{r.user.dus_id} -- school: #{sch ? "#{sch&.name}-#{r.home? ? sch&.allowed_home : sch&.allowed }" : 'missing'}, grad: #{r.invite_rule.grad_year.presence || 'N/A'}-#{r.athlete.grad || 'missing'}, addr: #{r.address.rejected}")
          end
          yield(r.to_row, nil)
        rescue
          p $!.message, $!.backtrace unless quiet_failure
          yield([], user.id)
        end
      end
    end

    def initialize(mailing, first_invite_date)
      @first_invite_date = first_invite_date
      super(mailing)
      self
    end

    def to_row
      [
        user.id,
        user.dus_id,
        user.notes.where("message like 'Was Connected to Wrong School%'").exists?,
        user.interest.level,
        invites_count = (invites = user.mailings.invites).size,
        (home_invites = user.mailings.home_invites).size,
        (school_invites = user.mailings.school_invites).size,
        invites.where(failed: false).size,
        invites.where(failed: true).size,
        home_invites.where(failed: false).size,
        home_invites.where(failed: true).size,
        school_invites.where(failed: false).size,
        school_invites.where(failed: true).size,
        invites.where(sent: nil).exists?,
        *(
          self.class.sports_list.map do |sport|
            as = user.athlete.athletes_sports.find_by(sport: sport)
            if as
              if as&.invited_date.present?
                (as.invited_date < first_invite_date) ?
                  'LAST_YEAR' :
                  as.invited_date.to_s
              else
                if (invites_count == 1) && (as&.sport == athlete.sport)
                  invites.take&.sent&.to_s || 'NEXT_DATE'
                elsif as&.invited && invites.unsent.exists?
                  'NEXT_DATE'
                else
                  nil
                end
              end
            else
              'N/A'
            end
          end
        ),
        user.notes.where("message like '20__ Traveler'").exists?,
        home?,
        ok_invite?,
        certificate == "Y",
        state.abbr,
        sport.abbr_gender,
        athlete.grad,
        user.first&.rrd_safe,
        user.last&.rrd_safe,
        athlete.school.name&.rrd_safe,
        athlete.school.state.abbr,
        athlete.school.address&.city,
        athlete.school.address&.zip,
        athlete.school_id,
        address.id,
        user.stats&.rrd_safe,
        user.admin_url
      ]
    end

    def first_invite_date
      @first_invite_date
    end

    def first_invite_date=(value)
      @first_invite_date = value
    end
  end
end
