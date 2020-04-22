# encoding: utf-8
# frozen_string_literal: true

module Flight
  class Schedule < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================
    # self.table_name = "#{usable_schema_year}.flight_schedules"
    attribute :parent_schedule_pnr, :text
    attribute :rtaxr, :text

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :parent_schedule, class_name: 'Schedule', inverse_of: :sub_schedules, optional: true
    belongs_to :verified_by, class_name: 'User', inverse_of: :verified_schedules, optional: true

    has_many :sub_schedules, class_name: 'Schedule', foreign_key: :parent_schedule_id
    has_many :legs, inverse_of: :schedule, dependent: :destroy do
      def ordered_departing
        order(:departing_at)
      end

      def ordered_last_departing
        order(departing_at: :desc)
      end

      def ordered_arriving
        order(:arriving_at)
      end

      def ordered_last_arriving
        order(arriving_at: :desc)
      end

      def ordered
        ordered_departing
      end

      def first_departing
        ordered.limit(1).first
      end

      def last_departing
        ordered_last_departing.limit(1).first
      end

      def first_arriving
        ordered_arriving.limit(1).first
      end

      def last_arriving
        ordered_last_arriving.limit(1).first
      end
    end

    has_many :tickets, inverse_of: :schedule, dependent: :destroy
    has_many :travelers, through: :tickets,   inverse_of: :flight_schedules
    has_many :users,     through: :travelers, inverse_of: :flight_schedules

    accepts_nested_attributes_for :legs, allow_destroy: true, reject_if: -> (attributes){
      attributes.except(:is_subsidiary, :overnight).values.all? &:blank?
    }

    # == Validations ==========================================================
    validates_presence_of :pnr, :route_summary
    validates_uniqueness_of :carrier_pnr, allow_blank: true

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :check_active_year
    before_destroy :check_active_year

    before_save :set_numbers, if: :rtaxr?
    before_save :find_parent_schedule, if: :parent_schedule_pnr?
    before_validation :set_rs_skip_save
    before_validation :format_values

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.default_print
      [
          :id,
          :pnr,
          :carrier_pnr,
          :seats_reserved,
          :names_assigned,
          :route_summary,
          :operator,
          :booking_reference,
          :verified_by_id,
      ]
    end

    def self.parse_time_zones(path)
      d = DateTime.new(2020, 7, 1, 0, 0)

      error_rows = []

      CSV.foreach path, headers: true do |row|
        begin
          if row['code'].present?
            info = ActiveSupport::TimeZone.find_tzinfo row['zone']
            period = info.period_for_local(d)
            if ap = Airport.find_by(code: row['code'])
              ap.update!(time_zone: period.offset.utc_total_offset)
            elsif row['zone'] =~ /(America|Australia|Pacific)/i
              Airport.create!(code: row['code'], name: row['name'], preferred: false, time_zone: period.offset.utc_total_offset, selectable: false)
            end
          end
        rescue
          puts row
          error_rows << row.to_h
          puts $!.message
          puts $!.backtrace.first(10)
        end
      end

      error_rows
    end

    def self.test!
      str = File.read(Rails.root.join('tmp', 'pnr_test.txt'))
      str.presence && parse!(str)
    end

    def self.parse!(amadeus)
      transaction do
        lines = amadeus.strip.split("\n").map &:strip

        raise 'Invalid First Line' unless lines.shift =~ /^\-\-\-/

        pnr = lines.shift[/.*\s([A-Z0-9]+)/, 1]
        operator = pnr.present? ? 'Qantas' : nil

        pnr_idx = 0

        while pnr.blank? && ((pnr_idx += 1) < 3)
          line = lines.shift
          pnr = line[/(?:AC|VA).*?\-([A-Z0-9]+)/, 1]
          if pnr.present?
            operator = (line =~ /AC.*?\-([A-Z0-9]+)/) ? 'Air Canada' : 'Virgin Australia'
          end
        end

        raise 'PNR not found from template' unless pnr.present?

        schedule = find_by(pnr: pnr.upcase) || new(pnr: pnr.upcase)
        old_count = schedule.seats_reserved
        schedule.original_value = amadeus.strip
        schedule.operator = operator

        original_legs = schedule.legs.map &:id

        leg, sr, na, first_leg, last_leg, lines_done = nil

        line_check_reg =
          %r{
            \s*\d\s+.*
            (?:\s*(?:\*.*?)?E\*|[A-Z0-9]{3}\s+E\d+(?:\s+[A-Z0-9])?|\s[A-Z0-9]{6}|\d+\s+[A-Z][0-9]\s+[A-Z])
            $
          }x

        line_parse_reg =
          %r{
            \s*\d\s+
            (\w+\s?\d+)
            \s[A-Z]\s
            (\d?\d...)
            \s\d\s
            ([A-Z]{3})
            ([A-Z]{3})
            .*?
            (\d+[A-Z](?:\+\d)?)
            \s*
            (\d+[A-Z](?:\+\d)?)
            \s*
            (?:(?:\*.*?)?E\*|[A-Z0-9]{3}\s+E\d+(?:\s+[A-Z0-9])?|(?:\s)[A-Z0-9]{6}|\d+\s+[A-Z][0-9]\s+[A-Z])
            $
          }x

        is_a_line = ->(l) do
          !!(l =~ line_check_reg) \
          && !(l =~ /claim/i) \
          && !(l =~ /^\s*\d+\s+(AP|OSI|SSR)\s+/)
        rescue
          false
        end

        lines.each do |line|
          p   leg:        leg && leg.flight_number,
              line:       line,
              is_flight:  is_a_line.call(line),
              is_sub:     (line =~ /operated/i),
              is_counter: (line =~ /\d+\.\s+(\d+)ISSI.*?NM:\s+?(\d+)/)

          if !first_leg && ( line =~ /\d+\.\s+(\d+)[A-Z+].*?NM:\s+?(\d+)/ )

            sr, na = line.match(/\d+\.\s+(\d+)[A-Z]+.*?NM:\s+?(\d+)/).to_a[1..-1]

            schedule.names_assigned = na.to_i
            schedule.seats_reserved = sr.to_i + schedule.names_assigned

          elsif !first_leg && ( line =~ /\d+\.[A-Z]+\s?[A-Z0-9]+\/[A-Z]+/ )

            sr = line.scan(/(\d+)\./).flatten.last

            schedule.names_assigned = sr.to_i
            schedule.seats_reserved = sr.to_i

          elsif ( line =~ /APE\s.*?\@DOWNUNDERSPORTS\.COM/i )

            lines_done = true

          elsif !lines_done && is_a_line.call(line)

            line_failed    =
            flight_number  =
            date           =
            departing_from =
            arriving_at    =
            departing      =
            arriving       = false

            begin
              flight_number,
              date,
              departing_from,
              arriving_to,
              departing,
              arriving =
                line.match(line_parse_reg).to_a[1..-1]
            rescue
              line_failed = true
            end

            unless line_failed || flight_number.blank?

              leg = schedule.legs.build
              first_leg ||= leg
              last_leg = leg

              leg.flight_number = "#{flight_number[/([A-Z]+)/, 1]} #{flight_number[/(\d+)/, 1]}"

              schedule.operator = 'Virgin Australia' if (schedule.operator == 'Qantas') && (leg.flight_number =~ /^VA\s\d+$/)

              leg.departing_airport_code = departing_from
              leg.arriving_airport_code = arriving_to

              raise leg.errors.full_messages.join("\n") unless leg.errors.empty?

              date =
                Date.new(
                  2020,
                  Date::ABBR_MONTHNAMES.index(date[/([A-Z]+)/, 1].titleize),
                  date[/(\d+)/, 1].to_i
                )

              leg.local_departing_at =
                DateTime.new(*twelve_to_twenty_four(date, departing))
              leg.local_arriving_at =
                DateTime.new(*twelve_to_twenty_four(date, arriving))

              leg.overnight = leg.local_departing_at.to_date < leg.local_arriving_at.to_date

            end

          elsif line =~ /operated/i
            raise 'Invalid PNR string' unless leg

            leg.is_subsidiary = true
            leg = false
          end
        end

        if !sr
          schedule.seats_reserved = 0
          schedule.names_assigned = 0
        end

        if first_leg.present?
          schedule.route_summary = "#{
              first_leg.departing_airport_code
            }#{
              first_leg.local_departing_at.to_date.to_s
            }#{
              last_leg.arriving_airport_code
            }#{
              last_leg.local_arriving_at.to_date.to_s
            }"
        else
          schedule.route_summary = "NOLEGS"
          schedule.seats_reserved = 0
          schedule.names_assigned = 0
        end

        raise schedule.errors.full_messages unless schedule.save

        Flight::Leg.where(id: original_legs).destroy_all

        schedule
      end
    end

    def self.twelve_to_twenty_four(date, time)
      hr = time[/(\d+)\d\d/, 1].to_i
      min = time[/\d+(\d\d)/, 1].to_i
      pm = time =~ /P/
      noon = hr == 12
      if noon
        hr = pm ? 12 : 0
      elsif pm
        hr += 12
      end

      add_days = time[/\w+\+(\d)/, 1].to_i
      d = date + add_days

      [d.year, d.month, d.day, hr, min, 0]
    end

    # == Boolean Methods ======================================================
    def verified?
      !!verified
    end

    # == Instance Methods =====================================================
    def find_parent_schedule
      self.parent_schedule = self.class.find_by(pnr: parent_schedule_pnr.strip.upcase)
    end

    def format_values
      %w[
        pnr
        carrier_pnr
        route_summary
        booking_reference
      ].each do |k|
        self.__send__ "#{k}=", self.__send__(k).to_s.strip.upcase.presence
      end
      self.operator = self.operator.to_s.strip.presence
    end

    def history(method = :pnr)
      sch = self
      values = [sch.__send__(method)]

      while sch.parent_schedule
        sch = sch.parent_schedule
        values << sch.__send__(method)
      end

      values
    end

    def set_numbers
      return false unless (lines = rtaxr.to_s.split("\n").map(&:strip)) && lines.shift =~ /AXR FOR PNR.*?#{pnr}/i
      f_pnr = nil
      rtaxr = nil
      lines.each do |line|
        sr, na, c_pnr = lines.shift.match(/\d+\..*?(\d+)\/(\d+)\s*?(\*|[A-Z0-9]+)$/).to_a[1..-1]
        if (sch = (c_pnr == '*') ? self : self.class.find_by(pnr: c_pnr.strip.upcase))
          if f_pnr
            sch.parent_schedule_pnr = f_pnr
          else
            sch.parent_schedule = nil
            f_pnr = sch.pnr
          end
          sch.rtaxr = nil
          unless sch.route_summary =~ /nolegs/i
            sch.names_assigned = na.to_i
            sch.seats_reserved = sr.to_i
          end
          sch.save
        end
      end
    end

    def set_route_summary(skip_save = false)
      ors = self.route_summary || route_summary || route_summary_was

      unless skip_save
        if verified_by_id?
          ors = false
          self.verified_by_id = nil
        end
      end

      "CALLED ROUTE SUMMARY"
      if legs.present?
        first_leg = last_leg = legs.first
        legs.each do |leg|
          if leg.present?
            first_leg = leg if (leg.departing_at < first_leg.departing_at)
            last_leg = leg if (leg.arriving_at > last_leg.arriving_at)
          end
        end
        self.route_summary = route_summary = "#{first_leg.departing_airport_code}#{first_leg.local_departing_at.to_date.to_s}#{last_leg.arriving_airport_code}#{last_leg.local_arriving_at.to_date.to_s}"
      else
        self.route_summary = route_summary = "NOLEGS"
        self.seats_reserved = seats_reserved = 0
        self.names_assigned = names_assigned = 0
      end
      skip_save ||= self.route_summary == ors
      return self.save unless skip_save
      true
    end

    def set_rs_skip_save
      set_route_summary(true)
    end

    def top_level(method = nil)
      sch = self
      while sch.parent_schedule
        sch = sch.parent_schedule
      end
      if method
        sch.__send__(method)
      else
        sch
      end
    end

    def where_route_hash
      @where_route_hash ||= [
        "
          (travelers.departing_from = ?) AND
          (COALESCE(travelers.departing_date, teams.departing_date) = ?) AND
          (travelers.returning_to = ?) AND
          (COALESCE(travelers.returning_date, teams.returning_date) = ?)
        ",
        *route_summary.scan(/([A-Z]{3})(\d{4}\-\d{2}\-\d{2})/).to_a.flatten
      ]
    end

    set_audit_methods!
  end
end
