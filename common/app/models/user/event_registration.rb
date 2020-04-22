# encoding: utf-8
# frozen_string_literal: true

require_dependency 'user'

class User < ApplicationRecord
  class EventRegistration < ApplicationRecord
    # == Constants ============================================================
    EVENT_LIST = [
      '100 M',
      '200 M',
      '400 M',
      '800 M',
      '1500 M',
      '3000 M',
      '90 M Hurdles',
      '100 M Hurdles',
      '110 M Hurdles',
      '200 M Hurdles',
      '300 M Hurdles',
      '400 M Hurdles',
      '2000 M Steeple',
      'Long Jump',
      'Triple Jump',
      'High Jump',
      'Pole Vault',
      'Shot Put',
      'Discus',
      'Javelin',
      'Hammer',
      '3000 M Walk',
      '5000 M Walk',
    ]

    AGE_REG = /(\_\d{2})+\z/i

    AGE_GROUPS = [14, 16, 18, 20]

    EVENT_TIME_RANGES = {
      event_100_m_time:          [ 9, 20 ],
      event_200_m_time:          [ 20, 30 ],
      event_400_m_time:          [ 40, 80 ],
      event_800_m_time:          [ 120, 180 ],
      event_1500_m_time:         [ 270, 360 ],
      event_3000_m_time:         [ 600, 900 ],
      event_90_m_hurdles_time:   [ 10, 20 ],
      event_100_m_hurdles_time:  [ 10, 20 ],
      event_110_m_hurdles_time:  [ 10, 20 ],
      event_200_m_hurdles_time:  [ 20, 35 ],
      event_300_m_hurdles_time:  [ 35, 60 ],
      event_400_m_hurdles_time:  [ 40, 90 ],
      event_2000_m_steeple_time: [ 450, 600 ],
      event_3000_m_walk_time:    [ 600, 1800 ],
      one_hundred_m_relay:       [ 9, 20 ],
      four_hundred_m_relay:      [ 40, 80 ],
    }

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================
    belongs_to :user, inverse_of: :event_registration, touch: true
    belongs_to :submitter, class_name: 'User'

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================
    before_save :check_active_year
    before_destroy :check_active_year
    after_commit :send_mail, on: :create

    # == Class Methods ========================================================
    def self.default_print
      [
        :id,
        :user_id,
        :total_event_count,
        :one_hundred_m_relay,
        :four_hundred_m_relay
      ]
    end

    def self.to_column_str(val)
      "event_#{val.to_s.parameterize.underscore.gsub(AGE_REG, '')}"
    end

    def self.event_params
      @@event_params ||= (EVENT_LIST.map do |ev|
        as_str = to_column_str(ev)
        [
          {as_str.to_sym => []},
          "#{as_str}_time".to_sym
        ]
      end.flatten + [:one_hundred_m_relay, :four_hundred_m_relay])
    end

    def self.fix_times(event, min, max)
      event = event.to_sym
      self.where.not(event => [nil, 'N/A']).map do |reg|
        original = reg.__send__(event)
        str = original.to_s.gsub(/(min|h)[A-Za-z]*/i, ':').sub(/sec[A-Za-z]*/i, '.').gsub(/[^0-9:.]/, '').split('.')

        str[0] = str[0].to_s.split(':').map(&:to_s).map {|v| v.rjust(2, '0')}
        str[0].unshift('00') while str[0].size < 3
        str[0] = str[0].join(':').to_i

        if (str[0] < min) || (str[0] > max)
          str = 'N/A'
        else
          str[1] = str[1].to_s[0..1]
          str = "00:#{(str[0] / 60).to_s.rjust(2, '0')}:#{(str[0] % 60).to_s.rjust(2, '0')}.#{str[1].ljust(2, '0')}"
        end

        reg.update(event => str) unless str == original

        "#{reg.id} | #{original} -- #{str}"
      end
    end

    def self.fix_all_times
      EVENT_TIME_RANGES.each do |k, v|
        puts fix_times(k, *v)
      end
    end

    def self.new(attributes = nil)
      event = super(attributes)
      event.send(:set_counts)
      event
    end

    # == Instance Methods =====================================================

    def reload
      @events = nil
      @relays = nil
      super
    end

    def add_event(ev, group, time = nil)
      str = to_column_str(ev)
      group = group.to_i
      raise ArgumentError.new("Age group must be one of: #{AGE_GROUPS.join(', ')}") unless group.in?(AGE_GROUPS)
      group = group == 20 ? '20+' : "#{group}/#{group + 1}"
      existing = ((event(ev) || []) + [group]).uniq.sort
      set_event(str, existing, (time || event_time(ev) || 'N/A'))
    end

    def remove_event(ev, group = :all)
      str = to_column_str(ev)
      raise ArgumentError.new("Age group must be one of: :all, #{AGE_GROUPS.join(', ')}") unless (group == :all) || group.to_i.in?(AGE_GROUPS)

      existing = (group == :all ? [] : (event(ev) || []).select {|age| age !~ Regexp.new(group.to_i.to_s)}) || []
      set_event(str, existing, (existing.size ? event_time(ev) : nil))
    end

    def set_event(col, ages, time)
      @events = nil
      __send__("#{col}=", ages)
      __send__("#{col}_time=", time)
      __send__("#{col}_count=", ages.size)
      __send__(col)
    end

    def has_event?(ev, group = nil)
      event_count(ev) > 0 && (group ? !!event("#{ev} #{group}") : true)
    end

    def details(full = false)
      {
        events: events(full),
        relays: relays,
      }
    end

    def events(full_details = nil)
      return @events if @events.present? && (@events[:full] == !!full_details)

      @events = { full: !!full_details }

      EVENT_LIST.each do |tf_event|
        if has_event?(tf_event)
          if full_details
            @events[tf_event] = {
              ages: event(tf_event),
              time: event_time(tf_event)
            } if has_event?(tf_event)
          else
            @events[tf_event] = event(tf_event)
          end
        end
      end
      @events
    end

    def relays
      return @relays if @relays.present?
      @relays = {}
      @relays["4 x 100 M Relay"] = one_hundred_m_relay if one_hundred_m_relay.present?
      @relays["4 x 400 M Relay"] = four_hundred_m_relay if four_hundred_m_relay.present?
      @relays
    end

    def event(ev)
      ev = ev.to_s.parameterize.underscore
      group = false
      if(ev =~ AGE_REG)
        group = (ev.slice (ev =~ AGE_REG), (ev.size - 1)).to_s.gsub('_', '')
      end

      evs = __send__(to_column_str(ev))

      return (evs.any? {|age| age =~ Regexp.new(group)} ? event_time(ev) || 'N/A' : nil) if group.present?

      evs
    end

    def event_time(ev)
      __send__("#{to_column_str(ev)}_time")
    end

    def event_count(ev)
      __send__("#{to_column_str(ev)}_count")
    end

    def set_event_count(ev, size)
      __send__("#{to_column_str(ev)}_count=", size)
    end

    def set_counts
      @events = {}
      EVENT_LIST.each do |tf_event|
        p tf_event
        p ev = event(tf_event)
        if(ev.size > 0)
          set_event_count(tf_event, ev.size)
          @events[tf_event] = event(tf_event)
        end
      end
      self
    end

    def total_event_count
      EVENT_LIST.map do |tf_event|
        event_count(tf_event)
      end.reduce(&:+)
    end

    def to_column_str(val)
      self.class.to_column_str(val)
    end

    private
      def send_mail
        # EventRegistrationMailer.athlete(self.id).deliver_later
        # EventRegistrationMailer.sports_credentials(self.id).deliver_later
        true
      end
  end
end
