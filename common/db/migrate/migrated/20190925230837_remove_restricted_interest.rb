class RemoveRestrictedInterest < ActiveRecord::Migration[5.2]
  def up
    if Interest.find_by(id: 8)&.level == 'Maybe Next Year'
      User.
        order(:id).
        where("interest_id > 7").
        split_batches_values(preserve_order: true) do |u|
          u.update(interest_id: u.interest_id - 1)
        end

      Interest.
        order(:id).
        where("id > 7").
        split_batches_values(preserve_order: true) do |interest|
          next_level = Interest.find_by(id: interest.id + 1)
          if next_level
            interest.update_columns(level: next_level.level)
          else
            interest.destroy
          end
        end
    end

    if Interest.find_by(id: 11)&.level == 'Restricted'
      User.
        order(:id).
        where("interest_id > 10").
        split_batches_values(preserve_order: true) do |u|
          u.update(interest_id: u.interest_id - 1)
        end

      Interest.find_by(id: 11).destroy
    end

    Interest.reset_cached_levels
  end
end
