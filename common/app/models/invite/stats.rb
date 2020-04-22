# encoding: utf-8
# frozen_string_literal: true

module Invite
  class Stats < ApplicationRecord
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.from_csv(path, clear = false)
      ### INCOMPLETE ###
      date = path[/.*\/[A-Z]+\-(\d+\-\d+\-\d+)\-.*/i, 1]
      stats = where(submitted: date) if date
      states = {}
      sports = {}
      bad_files = {}

      if stats && (stats.count > 0)
        if clear
          attrs = {}
          Sport.distinct.select(:abbr, :full).each do |sport|
            sports[sport.full] = sport
          end

          State.where(id: Team.distinct.pluck(:state_id)).each do |state|
            states[state.full] = state
            sports.each do |sport_full, sport|
              attrs["#{state.abbr}_#{sport.abbr}".downcase.to_sym] = 0
            end
          end
          attrs[:actual] = 0
          stats.update(attrs)
        end

        errors = []
        dates = {}
        CSV.foreach(path, headers: true, encoding: 'utf-8') do |row|
          begin
            hashed = row.to_h.with_indifferent_access
            date = "#{hashed[:date][/\d+\/\d+\/(\d+)/, 1]}-#{hashed[:date][/(\d+)\/\d+\/\d+/, 1]}-#{hashed[:date][/\d+\/(\d+)\/\d+/, 1]}"
            state = nil
            if  hashed[:statefull].present?
              state = states[hashed[:statefull]] || State.find_by_value(hashed[:statefull])
              states[hashed[:statefull]] ||= state
            else
              u = User.find_by_dus_id(hashed[:dusid])
              state = (u && u.team.state) || (states[hashed[:state]] || (states[hashed[:state]] = State.find_by_value(hashed[:state])))
            end

            sport = sports[hashed[:sportfull]] || Sport.find_by(full: hashed[:sportfull])
            sports[hashed[:sportfull]] ||= sport
            if state.present? && sport.present? && date.present?
              dates[date] ||= {}
              dates[date]["#{state.abbr}_#{sport.abbr}".downcase] = (dates[date]["#{state.abbr}_#{sport.abbr}".downcase].to_i) + 1
              dates[date]['actual'] = dates[date]['actual'].to_i + 1
            else
              raise ActiveRecord::RecordNotFound
            end
          rescue
            p path
            bad_files[path] = bad_files[path].to_i + 1
            errors << row.to_h.merge({error: $!.message, error_line: $!.backtrace.first, csv: path})
          end
        end

        dates.each do |date, counts|
          if stat = stats.find_by(mailed: date)
            stat.update(counts)
          end
        end

        [errors, bad_files]
      end
    end

    def self.fill_in_the_blanks(submitted_date, max = 2)
      return false unless (submissions = where(submitted: submitted_date).order(:mailed)).count > 0

      puts "Mapping School Counts"
      school_counts = school_counts_for_fitb
      submissions = submissions.to_a
      submission = submissions.shift
      base = base_query_for_fitb
      total_mailings = base.count
      i = 0
      puts "Creating Mailings"
      base.split_batches(preserve_order: true) do |batch|
        break if submissions.blank? && Mailing.where(sent: submission.mailed).invites.count >= submission.estimated

        batch.each do |mailing|
          break unless submission
          print "Current Count: #{i += 1} of #{total_mailings}       \r"
          next unless (athlete = mailing.mailable) && athlete.respond_date.blank? && athlete.mailings.invites.
          where(failed: [nil, false]).
          where(Mailing.arel_table[:sent].gt(mailing.sent)).count == 0

          if school_counts[athlete.school_id].to_i <= max
            athlete.mailings.create(category: :invite_school, auto: true, is_home: false, explicit: true, sent: submission.mailed)
            submission = submissions.shift if Mailing.invites.where(sent: submission.mailed).count >= submission.estimated + 1000
          end
        end
      end
      print "Final Count: #{i} of #{total_mailings}             \n"
    end

    def self.school_counts_for_fitb
      school_counts = {}
      base = base_query_for_fitb
      total_mailings = base.count
      i = 0
      base.split_batches(preserve_order: true) do |batch|
        batch.each do |mailing|
          print "Checking #{i += 1} of #{total_mailings}      \r"
          next unless (athlete = mailing.mailable) &&
          athlete.
          mailings.
          invites.
          where(failed: [nil, false]).
          where(Mailing.arel_table[:sent].gt(mailing.sent)).
          count == 0

          school_counts[athlete.school_id] ||= 0
          school_counts[athlete.school_id] += 1
        end
      end
      print "\nDone Mapping School Counts\r\n"
      school_counts
    end

    def self.base_query_for_fitb
      Mailing.
      where(category: 'invite_home').
      where(Mailing.arel_table[:sent].lt(Date.new(2018,01,01))).
      joins(%q(INNER JOIN athletes ON athletes.id = mailings.mailable_id AND mailings.mailable_type = 'Athlete')).
      joins(%q(INNER JOIN users ON users.id = athletes.user_id)).
      joins(%q(INNER JOIN teams ON teams.id = users.team_id)).
      joins(%q(INNER JOIN sports ON sports.id = teams.sport_id)).
      joins(%q(JOIN (VALUES ('XC', 1), ('BBB', 1), ('FB', 2), ('GBB', 3), ('VB', 3), ('GF', 3), ('TF', 4)) as x(value, order_number) ON sports.abbr_gender = x.value)).
      where(%q(athletes.respond_date IS NULL)).
      where(%q(teams.sport_id IN (1,8,2,6))).
      order("x.order_number", :created_at)
    end

    def self.sports
      groups = {}
      sports = Team.group(:sport_id).pluck(:sport_id).sort
      sports.each do |sport_id|
        teams = Team.where(sport_id: sport_id).pluck(:name).map {|team_name| team_name.downcase.gsub(/\s/, '_')}
        sport = teams.first.split('_').last
        groups[sport] = teams.map(&:to_sym)
      end
      groups
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def format_mailed
      mailed.to_s(:long)
    end

    def sports
      stats = {}
      groups = self.class.sports
      groups.each do |sport, teams|
        stats[sport] = teams.map {|team_name| self.__send__(team_name)}.reduce(&:+)
      end
      stats
    end

    def ordered_sports
      sports.sort_by {|sport, teams| sport}
    end
  end
end
