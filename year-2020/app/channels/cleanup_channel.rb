class CleanupChannel < ApplicationCable::Channel
  # == Constants ============================================================
  CHANNEL_NAME = "cleanup_channel"
  ADMIN_IDS = %w[ SAMPSN SARALO GAYLEO ].freeze

  # == Attributes ===========================================================

  # == Extensions ===========================================================

  # == Connection ===========================================================
  def subscribed
    stream_from CHANNEL_NAME
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
    ActionCable.server.broadcast(CHANNEL_NAME, { user_id: current_user&.id, action: 'left' })
  end

  # == Actions ==============================================================
  def get_samples(data)
    ActionCable.server.broadcast(
      CHANNEL_NAME,
      {
        user_id: current_user&.id,
        action: 'samples',
        sample_ids: gen_sample_ids(data['sport']),
        admin: is_admin?
      }
    )
  end

  def can_view_stats(*)
    ActionCable.server.broadcast(CHANNEL_NAME, { action: 'stats', stats: loaded_stats || [] })
  end

  def is_admin(*)
    ActionCable.server.broadcast(CHANNEL_NAME, { user_id: current_user&.id, action: 'admin', admin: is_admin? })
  end

  def get_stats(data)
    if stats = loaded_stats(true)
      ActionCable.server.broadcast(CHANNEL_NAME, { action: 'stats', stats: stats })
    end
    unless stats && stats_are_recent?
      stats = gen_stats
      Rails.redis.set(:cleanup_stats, { stats: stats, last_generated: Time.zone.now.as_json }.to_json)
      ActionCable.server.broadcast(CHANNEL_NAME, { action: 'stats', stats: stats })
    end
  end

  def available(data)
    return unavailable(data.merge({ global: true })) unless AthletesSport.transfer_nil.find(data['id'])

    ActionCable.server.broadcast(
      CHANNEL_NAME,
      {
        id: data['id'],
        time: current_time_in_ms(data),
        user_id: current_user&.id,
        action: 'availability'
      }
    )
  end

  def send_stats_email(*)
    if is_admin?
      ReportMailer.with(dus_id: current_user&.dus_id).cleanup_stats.deliver_later
    end

    ActionCable.server.broadcast(
      CHANNEL_NAME,
      {
        user_id: current_user&.id,
        action: 'stats_email',
        sent: is_admin?
      }
    )
  end

  def unavailable(data)
    ActionCable.server.broadcast(
      CHANNEL_NAME,
      {
        id: data['id'],
        user_id: data[:global] ? nil : current_user&.id,
        action: 'unavailable'
      }
    )
  end

  private
    def last_refresh(reload = false)
      (stats = redis_values) &&
      Time.zone.parse(stats["last_generated"])
    rescue
      nil
    end

    def current_time_in_ms(data)
      data['time'].presence&.to_i ||
      (Time.zone.now.to_f * 1000)
    end

    def gen_sample_ids(sport = nil)
      q = AthletesSport.
        transfer_nil

      if sport.present?
        sport =
          Sport.
            where(abbr: sport).
            or(Sport.where(abbr_gender: sport)).
            select(:id)
        q = q.where(sport_id: sport)
      end

      undergrads =
        Athlete.
          where(Athlete.arel_table[:grad].gt(2020)).
          select(:id)

      uq = q.where(athlete_id: undergrads)
      q = uq if uq.count(:all) > 0

      q.
        order(Arel.sql('RANDOM()')).
        limit(100).
        pluck(:id)
    end

    def is_admin?
      current_user&.dus_id&.dus_id_format&.in?(ADMIN_IDS)
    end

    def loaded_stats(reload = false)
      redis_values(reload)&.[]("stats")&.presence
    end

    def stats_are_recent?(reload = false)
      !!(time = last_refresh(reload)) &&
      (time > 10.minutes.ago) &&
      !!loaded_stats
    rescue
      false
    end

    def redis_values(reload = false)
      return @redis_values.dup if !reload && defined?(@redis_values) && @redis_values.present?
      if (stats = Rails.redis.get(:cleanup_stats)).present?
        @redis_values = JSON.parse(stats).presence
      end
      @redis_values.dup
    rescue
      @redis_values = nil
    end

    def gen_stats
      @redis_values = nil

      [
        [ "Total", AthletesSport.transfer_nil.size ],
      ] +
        AthletesSport.
          transfer_nil.
          uniq_column_values(:sport_id).
          size.
          map {|k, v| [ Sport.find(k).abbr_gender, v ]}
    end
end
