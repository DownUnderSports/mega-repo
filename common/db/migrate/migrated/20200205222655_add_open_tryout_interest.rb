class AddOpenTryoutInterest < ActiveRecord::Migration[5.2]
  def up
    if Interest.find_by(id: 7)&.level == 'Next Year'
      t = Time.zone.now

      time_out_blocker = -> do
        if Time.zone.now - t > 5.minutes
          puts "\nTIMEOUT BLOCKER\n"
          t = Time.zone.now
        end
      end

      Interest.
        order(id: :desc).
        where("id > 7").
        split_batches_values(preserve_order: true) do |interest|
          time_out_blocker.call

          previous_level = Interest.find_by(id: interest.id - 1)
          if previous_level
            interest.update_columns(level: previous_level.level)
          else
            interest.destroy
          end
        end

      Interest.find_by(id: 7).update_columns(level: 'Open Tryout', contactable: true)
      Interest.create(id: 11, level: 'Never', contactable: false)

      User.
        order(:id).
        where("interest_id > 6").
        split_batches_values(preserve_order: true) do |u|
          time_out_blocker.call

          u.update(interest_id: u.interest_id + 1)
        end
    end

    Interest.reset_cached_levels
  end
end
