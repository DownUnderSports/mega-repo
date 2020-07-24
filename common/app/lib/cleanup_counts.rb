class CleanupCounts
  DUS_IDS = %w[
    GAYLEO
    DANIEL
    SHRRIE
    KARENJ
    MSBLIF
    HZXJZL
  ]

  ACTIONS =
    AthletesSport::LoggedAction.
      where(row_id: AthletesSport.where.not(transferability: nil).select(:id)).
      where("changed_fields ? 'transferability'").
      where(action: "U")

  class << self
    def stats
      return @stats if defined? @stats
      @stats = []
      @stats
    end

    def format_stat(stat)
      <<~TEXT
        -- #{stat["name"]} --
            Total Count: #{stat["count"] || 0}
            Since Midnight: #{stat[Date.today.to_s] || 0}
            Since Yesterday: #{stat[Date.yesterday.to_s] || 0}
            Since #{monday.inspect}: #{stat[monday.to_s] || 0}
            Since #{last_monday.inspect}: #{stat[last_monday.to_s] || 0}
            Since #{two_mondays_ago.inspect}: #{stat[two_mondays_ago.to_s] || 0}
      TEXT
    end

    def print_stat(stat)
      puts format_stat(stat)
    end

    def print_stats
      stats.each {|stat| print_stat stat }
    end

    def run(print: false, **opts)
      collect_stats(**opts)

      print_stats if print

      stats
    end

    private
      def collect_stats(force: false, dus_ids: nil)
        force ||= stale?
        dus_ids && (dus_ids.map! {|v| v.to_s.dus_id_format! })
        new_stats = []
        filter = gen_filter(force, dus_ids)
        DUS_IDS.each do |id|
          new_stats << load_stat(id, filter)
        end
        new_stats << load_stat("TOTAL", filter, total: true, actions: ACTIONS)

        set_filter_date

        @stats = new_stats
      end

      def load_stat(target, filter, total: false, actions: nil)
        catch(:loaded) do
          catch(:reload) do
            value = filter.(target)
            @was_filtered = true
            throw :loaded, value
          end

          if total
            name = target
          else
            u = User[target]
            name = u.print_names
          end

          throw :loaded, fetch_stat(target: target, name: name, id: u&.id, actions: actions)
        end
      end

      def fetch_stat(target:, name:, id: nil, actions: nil)
        blocker_car.call
        actions ||= ACTIONS.where(app_user_id: id, app_user_type: "users")
        set_id(target, get_timed_counts(actions, { name: name }))
      end

      def stale?
        !recent_refresh?
      end

      def recent_refresh?
        rf = last_refresh
        rf&.>(30.minutes.ago) &&
        rf&.>(Time.zone.now.midnight)
      end

      def last_refresh
        (snt = get_filter_date).presence &&
        Time.zone.parse(snt)
      end

      def get_id(id)
        value = redis.get("cleanup_stat_#{id}")
        throw(:reload) unless value.present?
        JSON.parse(value)
      end

      def set_id(id, value)
        redis.set("cleanup_stat_#{id}", value.to_json)
        value
      end

      def redis
        Rails.redis
      end

      def gen_filter(force, dus_ids)
        if force
          proc { throw(:reload) }
        elsif dus_ids&.present?
          proc do |id|
            throw(:reload) if dus_ids.include?(id)
            get_id(id)
          end
        else
          proc {|id| get_id(id) }
        end

      end

      def get_timed_counts(actions, value)
        blocker_car.call
        value[:count] = actions.count(:all)
        return value.as_json unless value[:count] > 0
        [
          Date.today,
          Date.yesterday,
          monday,
          last_monday,
          two_mondays_ago
        ].each do |date|
          blocker_car.call
          value[date.to_s] ||= actions.
              where(table[:action_tstamp_tx].gteq(date.in_time_zone)).
              count(:all)
        end
        blocker_car.call
        value.as_json
      end

      def blocker_car
        return @blocker_car if defined? @blocker_car
        @blocker_car = generate_console_timeout_blocker
        @blocker_car
      end

      def table
        AthletesSport::LoggedAction.arel_table
      end

      def get_filter_date
        redis.get("cleanup_user_stats_last_fetched")
      end

      def set_filter_date
        was_filtered = @was_filtered
        @was_filtered = nil
        redis.set("cleanup_user_stats_last_fetched", Time.zone.now.utc.as_json) unless was_filtered
      end
  end
end
