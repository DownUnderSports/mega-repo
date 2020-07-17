class CleanupChannel < ApplicationCable::Channel
  # == Constants ============================================================
  CHANNEL_NAME = "cleanup_channel"
  ADMIN_IDS = %w[ SAMPSN SARALO GAYLEO KARENJ ].freeze

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
        stats: allowed_stats
      }
    )
  end

  def can_view_stats(*)
    ActionCable.server.broadcast(CHANNEL_NAME, { user_id: current_user&.id, action: 'stats', stats: allowed_stats })
  end

  def get_stats(data)
    ActionCable.server.broadcast(CHANNEL_NAME, { user_id: current_user&.id, action: 'stats', stats: gen_stats })
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

    def allowed_stats
      return nil unless current_user&.dus_id&.dus_id_format&.in?(ADMIN_IDS)
      []
    end

    def gen_stats
      allowed_stats && (
        [
          [ "Total", AthletesSport.transfer_nil.size ],
        ] +
          AthletesSport.
            transfer_nil.
            uniq_column_values(:sport_id).
            size.
            map {|k, v| [ Sport.find(k).abbr_gender, v ]}
      )
    end
end
