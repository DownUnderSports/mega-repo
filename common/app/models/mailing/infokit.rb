# encoding: utf-8
# frozen_string_literal: true

class Mailing < ApplicationRecord
  class Infokit
    def self.import_coach_nominations(csv_str)
      raise "WRONG YEAR" unless is_active_year?
      %w[
        athlete_dus_id
        coach_dus_id
        coach_name
        team_name
        gender
        stats
        school_name
        school_pid
        sport_abbr_gender
        grad
        first
        last
        phone
        email
        street
        city
        state_abbr
        zip
        parent_1_first
        parent_1_last
        parent_1_relationship
        parent_1_phone
        parent_1_email
        parent_2_first
        parent_2_last
        parent_2_relationship
        parent_2_phone
        parent_2_email
      ]

      csv = CSV.parse(csv_str, headers: true)
      i = 0
      par = 0
      urls = []
      csv.each do |r|
        begin
          i += 1
          r = r.to_h.deep_symbolize_keys
          school = School.find_by(pid: r[:school_pid].to_s)
          team = Team[r[:team_name]] || Team.find_by(sport: Sport[r[:sport_abbr_gender]], state: State[r[:state_abbr]])
          coach = User[r[:coach_dus_id]]
          source = Source.find_by(name: "Coach #{coach.basic_name}") ||
            Source.create(name: "Coach #{coach.basic_name}")
          u = nil

          if r[:athlete_dus_id].present?
            u = User[r[:athlete_dus_id]]
            u.athlete.referring_coach_id ||= coach.category_id
            u.athlete.source = source if u.athlete.referring_coach_id == coach.category_id
          end

          unless u ||= school.users.find_by(first: r[:first].titleize, last: r[:last].titleize)
            u = User.new(
              first: r[:first], last: r[:last], phone: r[:phone], email: r[:email],
              gender: r[:gender],
              category: Athlete.new(school: school, source: source, referring_coach_id: coach.category_id, sport_id: team.sport_id, original_school_name: r[:school_name])
            )
          end
          as = u.category.athletes_sports.find_by(sport_id: team.sport_id) ||
          u.category.athletes_sports.build(sport_id: team.sport_id)

          as.stats = "#{as.stats}\n#{r[:stats]}".strip

          unless u.respond_date.present?
            u.category.sport = team.sport
            as.invited = true
            u.address = Address.new(street: r[:street], city: r[:city], zip: r[:zip], state: State[r[:state_abbr]]) if r[:street].present?
            u.mailings.build(category: :infokit, address: r[:street].present? ? u.address : school.address)
          end

          par = 0
          loop do
            par += 1
            break unless r[:"parent_#{par}_first"].present?
            u.relations.build(relationship: r[:"parent_#{par}_relationship"], related_user: User.new(first: r[:"parent_#{par}_first"], last: r[:"parent_#{par}_last"],email: r[:"parent_#{par}_email"], phone: r[:"parent_#{par}_phone"])) unless u.related_users.find_by(first: r[:"parent_#{par}_first"], last: r[:"parent_#{par}_last"])
          end

          u.save!
          urls << u.url(1)
        rescue
          p i
          p $!.message
        end
      end
      urls
    end

    def self.headers
      %w{first last extra school address city state zip date date_long state_full sport_full athlete_intro athlete_paragraph_1 athlete_paragraph_2 athlete_paragraph_3 athlete_paragraph_4 athlete_closing parent_intro parent_paragraph_1 parent_paragraph_2 parent_paragraph_3 parent_paragraph_4 parent_paragraph_5 parent_closing dus_id url}
    end

    def self.csv_rows(params = {})
      date = Date.parse(params[:date].presence || Date.today.to_s)
      mailings = Mailing.where(category: 'infokit', failed: false, printed: false)

      mailings.
      find_each(batch_size: 100) do |record|
        begin
          record.update!(printed: true, sent: date)
          r = new(record).allowed_record
          values = r.to_row
          yield values if block_given?
        rescue
          p $!.message
          p $!.backtrace
          record.update(failed: true)
        end
      end
    end

    def initialize(mailing)
      @mailing = Mailing.get(mailing)
      @user = @mailing.user
      @athlete = @user.category
    end

    def check_allowed
      if !home?
        raise "Not Allowed" unless @athlete.school.allowed? &&
                                   !@athlete.school.closed?
      end
    end

    def allowed_record
      check_allowed
      self
    end

    def override(overrides)
      p overrides, overrides["invite_rule"]
      @extra = nil

      if !overrides['is_home'].nil?
        @address = nil
        @mailing.is_home = Boolean.parse(overrides['is_home'])
        @inbuilt = Boolean.parse(overrides['is_home'])
        @mailing.address ||= Address.first if @inbuilt
      end

      %w[
        address
        athlete
        date
        departing
        dus_id
        extra
        inbuilt
        invited_athlete_sport
        mailing
        school_name
        sport
        state
        user
      ].each {|k| instance_variable_set("@#{k}", overrides[k]) unless overrides[k].nil? }
      self
    end

    def home?
      !!(inbuilt_addr && @mailing.is_home)
    end

    def to_row
      # LEFT OVER ALWAYS NIL
      # - certificate_sentence
      [
        @user.first,
        @user.last,
        extra,
        school_name,
        street,
        address.city,
        address.state.abbr,
        address.zip,
        date.strftime("%m/%d/%Y"),
        date.strftime("%A, %B %e, %Y"),
        state.full,
        sport.full,
        athlete_intro.strip,
        athlete_paragraph_1.strip,
        athlete_paragraph_2.strip,
        athlete_paragraph_3.strip,
        athlete_paragraph_4.strip,
        athlete_closing.strip,
        parent_intro.strip,
        parent_paragraph_1.strip,
        parent_paragraph_2.strip,
        parent_paragraph_3.strip,
        parent_paragraph_4.strip,
        parent_paragraph_5.strip,
        parent_closing.strip,
        dus_id,
        "d.us/k/#{@mailing.id}"
      ]
    end

    def extra
      @extra ||= home? ? nil : "(#{sport.full})".downcase
    end

    def school_name
      @school_name ||= home? ? nil : @athlete.school.name
    end

    def street
      address.to_s(:streets)
    end

    def date
      @date ||= @mailing.sent || Date.today
    end

    def athlete_intro
      <<-PARAGRAPH
        Dear #{@user.first},
      PARAGRAPH
    end

    def athlete_paragraph_1
      return <<-PARAGRAPH
        Congratulations on being invited to represent #{state.full} at the 2020 Down Under #{sport.info.title} hosted on the Gold Coast of Australia.
      PARAGRAPH
    end

    def athlete_paragraph_2
      return <<-PARAGRAPH
        The Down Under Sports Tournaments will take place in the summer of 2020 with competition in football, cross country, golf, track and field, basketball and volleyball. Our #{sport.full} teams will depart on #{departing} and spend ten days traveling, competing and sight-seeing in Brisbane and on the Gold Coast of Australia. This is the Australia Tournament Package with the option to visit the Great Barrier Reef.
      PARAGRAPH
    end

    def athlete_paragraph_3
      return <<-PARAGRAPH
        Please read through the material in this information packet and view our information video at www.downundersports.com/videos/#{dus_id} with a parent/guardian. This video covers most questions you may have about our program.
      PARAGRAPH
    end

    def athlete_paragraph_4
      return <<-PARAGRAPH
        This is truly a once-in-a-lifetime opportunity. We ask that you give this your full consideration and make a timely decision as there are a limited number of spots available. If you have any questions or concerns, please call or text us at 435-753-4732.
      PARAGRAPH
    end

    def athlete_closing
      return <<-PARAGRAPH
        Sincerely,
      PARAGRAPH
    end

    def parent_intro
      return <<-PARAGRAPH
        To the Parents/Guardians of #{@user.first}:
      PARAGRAPH
    end

    def parent_paragraph_1
      return <<-PARAGRAPH
        We would like to congratulate you on #{@user.first}'s invitation to represent #{state.full} on the 2020 #{sport.full} Team. Each year we have a great group of athletes that compete in our tournaments and you should be proud that #{@user.first} was invited for this program. With #{@user.first}'s help, the team will have a good chance of bringing back the 2020 #{sport.info.tournament} Championship Title.
      PARAGRAPH
    end

    def parent_paragraph_2
      return <<-PARAGRAPH
        We hope the material enclosed will answer a lot of your questions about our sports program and help you to make an informed decision. For most families, the main concerns are cost, safety, and supervision. Down Under Sports has addressed these concerns in this information packet and would like to help you fully understand how they can be approached in a simple but effective way. Our fundraising program can and does cover the cost of this event, along with special offers to reduce the cost of the trip. Over the past 31 years, we have developed security procedures that are designed with the safety of each athlete and supporter in mind. Our Down Under Sports staff and coaches are involved in every aspect of the trip to ensure the running of a safe and well-supervised program.
      PARAGRAPH
    end

    def parent_paragraph_3
      return <<-PARAGRAPH
        After reading the material, please view our information video at www.downundersports.com/videos/#{dus_id} to answer most questions you may have about our program.
      PARAGRAPH
    end

    def parent_paragraph_4
      return <<-PARAGRAPH
        #{@user.first} is one of our top choices to represent #{state.full} on the 2020 #{sport.full} Team and, as always, parents and family are welcome to accompany their athletes on the trip. If #{@user.first} is unable to go, please let us know as soon as possible so we have time to select an alternate.
      PARAGRAPH
    end

    def parent_paragraph_5
      return <<-PARAGRAPH
        We look forward to hearing from you.
      PARAGRAPH
    end

    def parent_closing
      return <<-PARAGRAPH
        Sincerely,
      PARAGRAPH
    end

    def dus_id
      @dus_id ||= @user.dus_id
    end

    def departing
      @departing ||= sport.info.departing_dates
    end

    def invited_athlete_sport
      @invited_athlete_sport ||= @athlete.athletes_sports.where(invited: true).order(:invited_date).first
    end

    def sport
      @sport ||= @user.team&.sport || @athlete.super_sport || (invited_athlete_sport && invited_athlete_sport.sport)
    end

    def state
      @state ||= @user.team&.state || address.state
    end

    def track_number
      ((state.abbr =~ /HI/) || (state.conference =~ /(Central|Mountain)/)) ? 1 : 2
    end

    def address
      @address ||= Address.new(@mailing.address || @athlete.school.address&.attributes)
    end

    def inbuilt_addr
      @inbuilt ||= !!@mailing.address
    end
  end
end
