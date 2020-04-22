# encoding: utf-8
# frozen_string_literal: true

module Views
  module Assignments
    module Travelers
      def self.table_name
        "#{usable_schema_year}.#{table_name_only}"
      end

      def self.table_name_only
        "assignments_travelers_view"
      end

      def self.destroy(migration)
        migration.execute("DROP MATERIALIZED VIEW IF EXISTS #{table_name.sub(current_schema_year, 'public')} CASCADE")
        migration.execute("DROP MATERIALIZED VIEW IF EXISTS #{table_name} CASCADE")
      end

      def self.create(migration)
        return false unless table_exists?
        migration.execute(
          <<-SQL
            CREATE MATERIALIZED VIEW #{table_name}
            WITH (autovacuum_vacuum_threshold='50', autovacuum_vacuum_scale_factor='0.2')
            AS
              #{sql}
            WITH DATA
          SQL
        )

        migration.add_index table_name, :id,             name: "traveler_assignment_views_id_idx",             unique: true
        migration.add_index table_name, :dus_id,         name: "traveler_assignment_views_dus_id_idx"          # unique: false
        migration.add_index table_name, :assigned_to_id, name: "traveler_assignment_views_assigned_to_id_idx"  # unique: false
        migration.add_index table_name, :assigned_by_id, name: "traveler_assignment_views_assigned_by_id_idx"  # unique: false
        migration.add_index table_name, :completed,      name: "traveler_assignment_views_completed_idx"       # unique: false
        migration.add_index table_name, :unneeded,       name: "traveler_assignment_views_unneeded_idx"        # unique: false
        migration.add_index table_name, :reviewed,       name: "traveler_assignment_views_reviewed_idx"        # unique: false
        migration.add_index table_name, :created_at,     name: "traveler_assignment_views_created_at_idx"      # unique: false
        migration.add_index table_name, :sport_id,       name: "traveler_assignment_views_sport_id_idx"        # unique: false
        migration.add_index table_name, :state_id,       name: "traveler_assignment_views_state_id_idx"        # unique: false
        migration.add_index table_name, :team_name,      name: "traveler_assignment_views_team_name_idx"       # unique: false
        migration.add_index table_name, :tz_offset,      name: "traveler_assignment_views_tz_offset_idx"       # unique: false
        migration.add_index table_name, :joined_at,      name: "traveler_assignment_views_joined_at_idx"       # unique: false
        migration.add_index table_name, :cancel_date,    name: "traveler_assignment_views_cancel_date_idx"     # unique: false

        migration.execute "CREATE INDEX #{table_name_only}_name_idx ON #{table_name} USING gin (name gin_trgm_ops);"
        migration.execute "CREATE INDEX #{table_name_only}_team_name_idx ON #{table_name} USING gin (team_name gin_trgm_ops);"
        migration.execute "CREATE INDEX #{table_name_only}_assigned_to_full_name_idx ON #{table_name} USING gin (assigned_to_full_name gin_trgm_ops);"
        migration.execute "CREATE INDEX #{table_name_only}_assigned_by_full_name_idx ON #{table_name} USING gin (assigned_by_full_name gin_trgm_ops);"
      end

      def self.table_exists?
        result = ActiveRecord::Base.connection.execute <<-SQL
          SELECT EXISTS (
            SELECT 1
            FROM   pg_catalog.pg_class c
            JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE  c.relname = 'staff_assignments'
            AND    c.relkind = 'r'
          )
        SQL

        result.first['exists']
      rescue Exception
        false
      end

      def self.summarize_messages(join_name, where_clause = nil)
        <<-SQL
          LEFT JOIN (
            SELECT
              user_messages.user_id,
              COUNT(user_messages.id) AS message_count,
              MAX(user_messages.created_at) AS last_messaged_at
            FROM "#{usable_schema_year}".user_messages
            INNER JOIN users message_users
              ON message_users.id = user_messages.user_id
            INNER JOIN (
              SELECT
                travelers.user_id,
                COALESCE(traveler_payments.created_at, travelers.created_at) AS joined_at
              FROM
                "#{usable_schema_year}".travelers
              LEFT JOIN "#{usable_schema_year}".payment_items traveler_payments
                ON (
                  traveler_payments.id = (
                    SELECT payment_items.id
                    FROM "#{usable_schema_year}".payment_items
                    INNER JOIN "#{usable_schema_year}".payments
                    ON payments.id = payment_items.payment_id
                    WHERE (
                      traveler_id = travelers.id
                      AND
                      payments.successful = TRUE
                    )
                    ORDER BY payment_items.created_at asc
                    LIMIT 1
                  )
                )
            ) travelers
              ON travelers.user_id = user_messages.user_id
            INNER JOIN staffs
              ON staffs.id = user_messages.staff_id
            INNER JOIN users message_staff_user
              ON
                (message_staff_user.category_id = staffs.id)
                AND
                (message_staff_user.category_type = 'staffs')
            WHERE
              (NOT user_messages.type IN ('User::Alert'))
              AND
              (NOT message_staff_user.dus_id = 'AUTOWK')
              #{
                where_clause ? "AND\n(#{where_clause})" : ''
              }
            GROUP BY user_messages.user_id
          ) #{join_name}
            ON #{join_name}.user_id = users.id
        SQL
      end

      def self.sql
        <<-SQL
          SELECT DISTINCT
            staff_assignments.*,
            staff_assignments_were_visited.visited,
            (assigned_to_users.first || ' ' || assigned_to_users.last) AS assigned_to_full_name,
            (assigned_by_users.first || ' ' || assigned_by_users.last) AS assigned_by_full_name,
            COALESCE(message_history.message_count, 0) AS message_count,
            COALESCE(pre_signup_message_history.message_count, 0) AS pre_signup_message_count,
            COALESCE(post_signup_message_history.message_count, 0) AS post_signup_message_count,
            message_history.last_messaged_at,
            users.dus_id,
            (COALESCE(users.first, '') || ' ' || COALESCE(users.last, '')) AS name,
            states.id AS state_id,
            sports.id AS sport_id,
            teams.name AS team_name,
            COALESCE(addresses.tz_offset, states.tz_offset) AS tz_offset,
            COALESCE(interests.level, 'Unknown') AS interest_level,
            COALESCE(interests.id, 0) AS interest_id,
            travelers.joined_at,
            travelers.cancel_date
          FROM "#{usable_schema_year}".staff_assignments
          INNER JOIN users
            ON
              users.id = staff_assignments.user_id
          INNER JOIN users assigned_to_users
            ON assigned_to_users.id = staff_assignments.assigned_to_id
          INNER JOIN users assigned_by_users
            ON assigned_by_users.id = staff_assignments.assigned_by_id
          INNER JOIN (
            SELECT
              travelers.*,
              COALESCE(traveler_payments.created_at, travelers.created_at) AS joined_at
            FROM
              "#{usable_schema_year}".travelers
            LEFT JOIN "#{usable_schema_year}".payment_items traveler_payments
              ON (
                traveler_payments.id = (
                  SELECT payment_items.id
                  FROM "#{usable_schema_year}".payment_items
                  INNER JOIN "#{usable_schema_year}".payments
                  ON payments.id = payment_items.payment_id
                  WHERE (
                    traveler_id = travelers.id
                    AND
                    payments.successful = TRUE
                  )
                  ORDER BY payment_items.created_at asc
                  LIMIT 1
                )
              )
          ) travelers
            ON travelers.user_id = users.id
          INNER JOIN teams
            ON teams.id = travelers.team_id
          INNER JOIN states
            ON states.id = teams.state_id
          INNER JOIN sports
            ON sports.id = teams.sport_id
          #{summarize_messages('message_history')}
          #{summarize_messages('pre_signup_message_history', "user_messages.created_at < travelers.joined_at")}
          #{summarize_messages('post_signup_message_history', "user_messages.created_at >= travelers.joined_at")}
          LEFT JOIN addresses
            ON addresses.id = users.address_id
          INNER JOIN (
            SELECT
              id,
              CASE WHEN EXISTS (
                SELECT 1
                FROM "#{usable_schema_year}".staff_assignment_visits
                WHERE staff_assignment_visits.assignment_id = staff_assignments.id
              ) THEN TRUE
              ELSE FALSE
              END visited
            FROM "#{usable_schema_year}".staff_assignments
          ) staff_assignments_were_visited
            ON staff_assignments_were_visited.id = staff_assignments.id
          LEFT JOIN interests
            ON interests.id = users.interest_id
          WHERE
            staff_assignments.unneeded != TRUE
          AND
            staff_assignments.completed != TRUE
          AND
            staff_assignments.reason = 'Traveler'
        SQL
      end
    end
  end
end
