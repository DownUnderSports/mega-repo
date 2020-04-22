# encoding: utf-8
# frozen_string_literal: true

module Invite
  class Parser
    def self.fill_in_the_blanks(date, older_than: 2.weeks.ago.to_date, school_count: 6, max: 15000, min: 13000, max_school_count: 8, forwarded_only: false)
      raise NoMethodError.new(:invalid_range) if min > max

      count = Mailing.invites.where(sent: date, failed: false).count

      forwarded = Mailing.invites.includes(user: [{athlete: :school}]).where(sent: nil)
      query = Mailing.includes(user: [{athlete: :school}]).where(category: :invite_home).where('sent < ?', older_than.to_date) unless Boolean.parse(forwarded_only)
      max = [count + (query&.count.to_i + forwarded.count), max].min
      error = nil

      if count < max
        forwarded.order(:created_at).split_batches do |b|
          break if count >= max

          b.each do |m|
            error = nil
            u = m.user
            next if (count >= max) ||
              !u.interest.contactable ||
              u.respond_date.present?

            next if (
              !!(m.category.to_s =~ /school|explicit/) &&
              !!(
                Mailing.where(
                  user: u.athlete.school.users,
                  category: :invite_school,
                  sent: date
                ).count >= school_count
              )
            )

            begin
              Mailing.transaction do
                om = u.mailings.
                  where(category: m.category, failed: true).
                  where.not(sent: nil)

                sports = u.athlete.athletes_sports.order(:rank)

                (
                  (
                    Boolean.parse(forwarded_only) &&
                    sports.find_by(invited: true, invited_date: nil)
                  ) ||
                  (
                    (om.count != 0) &&
                    sports.find_by(
                      invited: true,
                      invited_date: om.select(:sent)
                    )
                  ) ||
                  sports.find_by(invited: true, invited_date: nil) ||
                  sports.find_by(invited: true) ||
                  sports.limit(1).take
                ).update!(invited_date: date)

                m.update!(sent: date)
              end
            rescue
              error = true
            end

            next if error

            break if (count += 1) >= max
          end
        end

        if count < max && !Boolean.parse(forwarded_only)
          query.order(:sent).split_batches do |b|
            break if count >= max

            b.each do |m|
              error = nil
              u = m.user
              next if (count >= max) ||
                !u.interest.contactable ||
                u.respond_date.present? ||
                !u&.athlete&.school&.address ||
                u.mailings.find_by(category: :invite_school)

              next if Mailing.where(user: u.athlete.school.users, category: :invite_school, sent: date).count >= school_count

              begin
                Mailing.transaction do
                  (
                    u.athlete.athletes_sports.find_by(invited: true, invited_date: m.sent ) ||
                    u.athlete.athletes_sports.order(:rank).limit(1).take
                  ).update!(invited_date: date)

                  u.mailings.create!(sent: date, category: :invite_school, address: u.athlete.school.address, is_home: false, explicit: true)
                end
              rescue
                error = true
              end

              next if error

              break if (count += 1) >= max
            end
          end
        end
      end

      return fill_in_the_blanks(date, older_than: older_than, school_count: school_count + 1, max: max, min: min, max_school_count: max_school_count, forwarded_only: false) if !Boolean.parse(forwarded_only) &&
        min &&
        (school_count < max_school_count) &&
        (Mailing.invites.where(sent: date, failed: false).count < min)

      Mailing.invites.where(sent: date, failed: false).count
    end

    def self.from_console(params)
      i = 0
      csv = +""
      files = []

      start_date = Date.parse(params[:start]).to_s
      end_date = Date.parse(params[:end].presence || params[:start]).to_s

      save_file = -> do
        files << (path = "invites-#{start_date}_#{end_date}_#{i}.csv")
        save_tmp_csv(path, csv)
        csv = +""
        puts "\n#{path}\n"
      end

      csv_rows({ quiet_failure: true, print_over_counted: true }.merge(params.to_h.deep_symbolize_keys)) do |r|
        if (i % 10_000) == 0
          save_file.call if i > 0
          csv << CSV.generate_line(headers, encoding: 'UTF-8')
        end
        if r.present?
          csv << CSV.generate_line(r, encoding: 'UTF-8')
          print "\r#{"#{i += 1}".rjust(7, '0')}"
        end
      end

      save_file.call

      files
    end

    def self.clear_dups
      sub_query =
        Mailing.
          invites.
          group(:category, :user_id, :sent, :failed).
          having("count(id) > 1").
          select("max(id) as id").
          order(:user_id).
          to_sql

      query =
        Mailing.
          joins("INNER JOIN (#{sub_query}) grouped ON mailings.id = grouped.id")

      query.destroy_all while query.size > 0
    end

    def self.headers
      %w[ date first last extra school address city state zip dusid heading1 heading2 paragraph1 paragraph2 paragraph3 closing certificate state_full certificate_sentence sportfull address_id ps_line sport_itinerary url ]
    end

    def self.csv_rows(params)
      clear_dups

      mailings =
        Mailing.
          where(failed: false).
          where(
            "sent BETWEEN ? AND ?",
            Date.parse(params[:start].us_date_to_iso_if_needed),
            Date.parse((params[:end] || params[:start]).us_date_to_iso_if_needed)
          )

      if params[:type].blank?
        mailings = mailings.invites
      else
        mailings = mailings.where(category: params[:type])
      end

      allowed_max = params[:max].presence&.to_i || 10_000_000

      dates = {}
      i = 0
      count = mailings.count
      values = nil
      successful = {}

      mailings.
      find_each(batch_size: 1000) do |record|
        values = nil
        begin
          Mailing.transaction do
            r = new(record)
            unless r.allowed
              sch = r.athlete&.school
              raise NoMethodError.new("#{i += 1} of #{count} -- NOT ALLOWED -- #{r.user.dus_id} -- school: #{sch ? "#{sch&.name}-#{r.home? ? sch&.allowed_home : sch&.allowed }" : 'missing'}, grad: #{r.invite_rule.grad_year.presence || 'N/A'}-#{r.athlete.grad || 'missing'}, addr: #{r.address.rejected}")
            end
            values = r.to_row

            if values.first.present? && block_given?
              date = r.mail_date_for_stats
              str = "#{r.state.abbr}_#{r.sport.abbr}".downcase

              if (successful[date] ||= 0) < allowed_max
                dates[date] ||= {}
                dates[date][str] = (dates[date][str].to_i) + 1
                dates[date]['actual'] = dates[date]['actual'].to_i + 1

                yield(values, nil)
              else
                print "\r#{"Over Counted: #{successful[date] + 1}".ljust(12, ' ')}" if params[:print_over_counted]

                r.invited_athlete_sport&.update!(invited_date: params[:next_date].presence, invited: true)
                record.update!(sent: params[:next_date].presence)
              end
              successful[date] += 1
            end
          end
        rescue ActiveRecord::ActiveRecordError, NameError
          p $!, $!.message, $!.backtrace unless Boolean.parse(params[:quiet_failure])
          yield([], record.id)

          record.update(failed: true)
        end
      end

      dates.each do |date, attrs|
        Stats.where(mailed: date).update(attrs)
      end
    end

    def initialize(mailing)
      @mailing = Mailing.get(mailing)
      @user = @mailing.user
      @athlete = @user.category
      @mailing.address = self.address
      @mailing.is_home = !!home?
      @mailing.category = "invite_#{!!(home?) ? 'home' : 'school'}"
      @mailing.save if @mailing.persisted? && @mailing.changed?
      @state = nil
      self
    end

    def override(overrides)
      p overrides, overrides["invite_rule"]
      %w[
        address
        athlete
        departing
        dus_id
        extra
        invited_athlete_sport
        invite_rule
        is_home
        mailing
        school_name
        sport
        sport_full
        state
        user
      ].each {|k| instance_variable_set("@#{k}", overrides[k]) unless overrides[k].nil? }
      self
    end

    def mailing
      @mailing
    end

    def user
      @user
    end

    def athlete
      @athlete
    end

    def allowed
      user.interest.contactable \
        && athlete.school \
        && !(athlete.school.name =~ /(deaf|blind)/) \
        && (home? ? athlete.school.allowed_home : athlete.school.allowed) \
        && (
            ( invite_rule.grad_year == current_year.to_i ) \
              ? ( athlete.grad && ( athlete.grad <= invite_rule.grad_year ) ) \
              : !(athlete.grad &.> (invite_rule.grad_year&.to_i || 2023))
          ) \
        && !(address.rejected)
    end

    def home?
      return @is_home unless @is_home.nil?
      @is_home ||= mailing.explicit? ? !!mailing.is_home : !!user.main_address&.unrejected
    end

    def to_row
      # LEFT OVER ALWAYS NIL
      # - certificate_sentence
      [
        invite_date,
        user.first&.rrd_safe,
        user.last&.rrd_safe,
        extra&.rrd_safe,
        school_name,
        street&.rrd_safe,
        address.city&.rrd_safe,
        address.state.abbr,
        address.zip,
        dus_id,
        tryout,
        second_heading,
        p1.strip,
        p2.strip,
        p3.strip,
        p4.strip,
        certificate,
        state.full,
        nil,
        sport_full,
        address.id,
        ps_line,
        sport_itinerary,
        "d.us/i/#{mailing.id}"
      ]
    end

    def certificate
      invite_rule.certifiable ? "Y" : nil
    end

    def p1
      if ok_invite?
        return <<-PARAGRAPH
          Down Under Sports is pleased to announce that #{certificate == 'Y' ? 'based on your overall performance ' : ''}you have been invited to represent #{state.full} at the 32nd annual Down Under Sports tournaments hosted on the Gold Coast of Australia. #{certificate == 'Y' ? 'We proudly present your certificate for this achievement (enclosed).' : ''}
        PARAGRAPH
      else
        return <<-PARAGRAPH
          You have been invited to the ONLINE OPEN TRYOUT for the 32nd annual Down Under Sports tournaments hosted on the Gold Coast of Australia. This tryout will culminate in the selection of our 2020 USA #{sport_full} Team. Be ready to discuss your sport stats, achievements, and any other qualities you would like us to consider in the selection process.
        PARAGRAPH
      end
    end

    def p2
      return <<-PARAGRAPH
        #{ok_invite? ? 'You' : 'If you are selected, you'} will join the ranks of thousands of exceptional athletes who have participated in this once-in-a-lifetime experience. Our #{sport_full.downcase} teams depart on #{departing} to meet up with our Down Under Sports coaches and staff and spend ten days traveling, competing and sight-seeing in Australia. See enclosed sample itinerary for more information.
      PARAGRAPH
    end

    def p3
      if ok_invite?
        return <<-PARAGRAPH
          We have developed a proven sponsorship fundraising program and special offers to help our athletes cover the cost of this event. Request a no obligation information packet at downundersports.com/#{dus_id} or call/text us at 435-753-4732. After submitting a request, along with a packet in the mail you'll receive a link to a short video for you to watch with a parent/guardian. This video will cover the most important details of our program, including available discounts, so you can make a well-informed decision.
        PARAGRAPH
      else
        return <<-PARAGRAPH
          To ensure that every selected athlete can participate in this once-in-a-lifetime experience, we have developed a proven sponsorship fundraising program and special offers to help our athletes cover the cost of this event. To try out for the team, request more information at downundersports.com/#{dus_id} or call/text us at 435-753-4732.
        PARAGRAPH
      end
    end

    def p4
      if ok_invite?
        return <<-PARAGRAPH
          We look forward to speaking with you about your invitation to compete in the land down under.
        PARAGRAPH
      else
        return <<-PARAGRAPH
          We look forward to hearing from you soon and hope to see you in the land down under.
        PARAGRAPH
      end
    end

    def ps_line
      "P.S. Check us out on social media and visit downundersports.com/sports/#{sport.abbr_gender} to see our #{sport_full.downcase} tournament archives."
    end

    def invite_rule
      @invite_rule ||= Rule.find_by(sport: sport, state: state)
    end

    def departing
      @departing ||= sport.info.departing_dates
    end

    def tryout
      ok_invite? ? "OFFICIAL #{sport.full_gender.upcase} INVITATION" : "ONLINE OPEN TRYOUT"
    end

    def second_heading
      ok_invite? ? nil : "#{state.full} #{sport.full_gender}"
    end

    def sport_itinerary
      sport.abbr
    end

    def ok_invite?
      !!invite_rule.invitable
    end

    def dus_id
      @dus_id ||= user.dus_id
    end

    def invited_athlete_sport
      @invited_athlete_sport ||=
        athlete.athletes_sports.find_by(invited: true, invited_date: mailing.sent) ||
        athlete.athletes_sports.find_by(sport: athlete.sport) ||
        athlete.athletes_sports.order(:rank).limit(1).take
    end

    def sport
      @sport ||= invited_athlete_sport.sport
    end

    def sport_full
      @sport_full ||= sport.full
    end

    def state
      @state ||= athlete.school.address.state
    end

    def invite_date
      mailing.sent.strftime("%m/%d/%Y")
    end

    def mail_date_for_stats
      mailing.sent.to_s
    end

    def extra
      @extra ||= home? ? nil : "(#{sport_full} athlete)".downcase
    end

    def track_number
      ((state.abbr =~ /HI/) || (state.conference =~ /(Central|Mountain)/)) ? 1 : 2
    end

    def school_name
      @school_name ||= home? ? nil : athlete.school.name&.rrd_safe
    end

    def street
      address.street_2 ? "#{address.street} #{address.street_2}" : address.street
    end

    def address
      if mailing.explicit?
        @address ||= home? ? user.main_address&.unrejected : athlete.school.address
      else
        @address ||= (home? && user.main_address&.unrejected) || athlete.school.address
      end || Address.new(rejected: true)
    end
  end
end
