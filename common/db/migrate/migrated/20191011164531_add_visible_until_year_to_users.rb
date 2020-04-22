class AddVisibleUntilYearToUsers < ActiveRecord::Migration[5.2]
  def up
    unless User.column_names.include? 'visible_until_year'
      execute "DROP TRIGGER audit_trigger_row ON users;"
      execute "DROP TRIGGER audit_trigger_stm ON users;"

      change_table :users do |t|
        t.rename :created_at, :was_created_at
        t.rename :updated_at, :was_updated_at

        t.integer :visible_until_year
        t.index [ :visible_until_year ]

        t.timestamps default: -> { 'NOW()' }
      end

      while User.where(visible_until_year: nil).size > 0
        execute <<-SQL
          UPDATE users
          SET
            created_at = was_created_at,
            updated_at = was_updated_at,
            visible_until_year = CASE
              WHEN category_type IN ('#{BetterRecord::PolymorphicOverride.all_types(Athlete).join("', '")}') THEN 2020
              WHEN category_type IS NULL THEN 2020
              ELSE 3000
            END
          WHERE
            users.id IN (
              SELECT
                id
              FROM users
              WHERE
                visible_until_year IS NULL
              LIMIT 20000
            )
        SQL
      end

      remove_column :users, :was_created_at
      remove_column :users, :was_updated_at

      audit_table :users, true, false, %w[ password register_secret certificate updated_at ]

      set_db_year 2020

      q = User.where(visible_until_year: 2020)
      updated_at = Time.zone.now

      fill_in_relations = -> do
        q.
         where_exists(:related_users, User.arel_table[:visible_until_year].gt(2020)).
          split_batches_values do |u|
            User.where(id: [
              u,
              *u.related_users.pluck(:id)
            ]).update_all(visible_until_year: u.related_users.try(:maximum, :visible_until_year) || 2021, updated_at: updated_at)
          end
      end

      Athlete.where(Athlete.arel_table[:grad].gt(2019)).uniq_column_values(:grad).pluck(:grad).each do |year|
        sub_q = q.joins(:athlete).where(athletes: { grad: year }).where.not(visible_until_year: year + 1)
        while sub_q.size > 0
          User.where(id: sub_q.select(:id).limit(20000)).update_all(visible_until_year: year + 1, updated_at: updated_at)
        end
      end

      fill_in_relations.call

      sub_q = q.where_exists(:traveler).
        or(q.where_exists(:mailings)).
        or(q.where.not(responded_at: nil)).
        or(q.where(User.arel_table[:created_at].gt(Time.zone.parse('2019-09-04'))))

      while sub_q.size > 0
        User.where(id: sub_q.select(:id).limit(20000)).update_all(visible_until_year: 2021, updated_at: updated_at)
      end

      fill_in_relations.call

      set_db_year "public"
    end
  end

  def down
    remove_column :users, :visible_until_year
  end
end
