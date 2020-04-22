# encoding: utf-8
# frozen_string_literal: true

module Views
  module Assignments
    module Responds
      def self.table_name
        "#{usable_schema_year}.#{table_name_only}"
      end

      def self.table_name_only
        "assignments_responds_view"
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

        migration.add_index(table_name, :id, unique: true)
        migration.add_index(table_name, :dus_id)
        migration.add_index(table_name, :assigned_to_id)
        migration.add_index(table_name, :assigned_by_id)
        migration.add_index(table_name, :completed)
        migration.add_index(table_name, :unneeded)
        migration.add_index(table_name, :reviewed)
        migration.add_index(table_name, :created_at)
        migration.add_index(table_name, :sport_id)
        migration.add_index(table_name, :state_id)
        migration.add_index(table_name, :team_name)
        migration.add_index(table_name, :tz_offset)
        migration.add_index(table_name, :watched_at)
        migration.add_index(table_name, :viewed_at)
        migration.add_index(table_name, :last_viewed_at)
        migration.add_index(table_name, :registered_at)

        migration.execute "CREATE INDEX #{table_name_only}_name_idx ON #{table_name} USING gin (name gin_trgm_ops);"
        migration.execute "CREATE INDEX #{table_name_only}_team_name_idx ON #{table_name} USING gin (team_name gin_trgm_ops);"
        migration.execute "CREATE INDEX #{table_name_only}_duration_idx ON #{table_name} USING gin (duration gin_trgm_ops);"
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
            COALESCE(pre_meeting_message_history.message_count, 0) AS pre_meeting_message_count,
            COALESCE(post_meeting_message_history.message_count, 0) AS post_meeting_message_count,
            COALESCE(other_message_history.message_count, 0) AS other_message_count,
            message_history.last_messaged_at,
            COALESCE(video_views.duration, '00:00:00') AS duration,
            video_views.first_watched_at AS watched_at,
            video_views.first_viewed_at AS viewed_at,
            CASE
              WHEN video_views.first_viewed_at IS NOT NULL THEN TRUE
              ELSE FALSE
            END AS viewed,
            CASE
              WHEN video_views.first_watched_at IS NOT NULL THEN TRUE
              ELSE FALSE
            END AS watched,
            video_views.last_viewed_at,
            video_views.created_at AS registered_at,
            users.dus_id,
            users.responded_at,
            (COALESCE(users.first, '') || ' ' || COALESCE(users.last, '')) AS name,
            states.id AS state_id,
            sports.id AS sport_id,
            (COALESCE(states.abbr, '') || ' ' || COALESCE(sports.abbr_gender, '')) AS team_name,
            COALESCE(addresses.tz_offset, school_addresses.tz_offset, states.tz_offset) AS tz_offset,
            COALESCE(interests.level, 'Unknown') AS interest_level,
            COALESCE(interests.id, 0) AS interest_id
          FROM "#{usable_schema_year}".staff_assignments
          INNER JOIN users
            ON
              users.id = staff_assignments.user_id
              AND
              users.category_type IS NOT NULL
          INNER JOIN users assigned_to_users
            ON assigned_to_users.id = staff_assignments.assigned_to_id
          INNER JOIN users assigned_by_users
            ON assigned_by_users.id = staff_assignments.assigned_by_id
          #{summarize_messages('message_history')}
          #{summarize_messages('pre_meeting_message_history', "user_messages.reason = 'pre-meeting'")}
          #{summarize_messages('post_meeting_message_history', "user_messages.reason = 'post-meeting'")}
          #{summarize_messages('other_message_history', "user_messages.reason NOT LIKE '%meeting'")}
          LEFT JOIN athletes
            ON (
              (athletes.id = users.category_id)
              AND
              (users.category_type = 'athletes')
            )
          LEFT JOIN coaches
            ON (
              (coaches.id = users.category_id)
              AND
              (users.category_type = 'coaches')
            )
          LEFT JOIN schools
            ON (
              schools.id = COALESCE(athletes.school_id, coaches.school_id)
            )
          LEFT JOIN addresses
            ON addresses.id = users.address_id
          LEFT JOIN addresses school_addresses
            ON school_addresses.id = schools.address_id
          LEFT JOIN states
            ON states.id = COALESCE(school_addresses.state_id, addresses.state_id)
          LEFT JOIN sports
            ON (
              sports.id = COALESCE(athletes.sport_id, coaches.sport_id)
            )
          LEFT JOIN (
            SELECT
              meeting_video_views.user_id,
              MAX(meeting_video_views.duration)::text AS duration,
              MIN(meeting_video_views.first_watched_at) AS first_watched_at,
              MIN(meeting_video_views.first_viewed_at) AS first_viewed_at,
              MAX(meeting_video_views.last_viewed_at) AS last_viewed_at,
              MIN(meeting_video_views.created_at) AS created_at
            FROM "#{usable_schema_year}".meeting_video_views
            INNER JOIN meeting_videos
              ON (
                (meeting_videos.id = meeting_video_views.video_id)
                AND
                (meeting_videos.category = 'I')
              )
            GROUP BY meeting_video_views.user_id
          ) video_views
            ON video_views.user_id = users.id
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
            staff_assignments.reason = 'Respond'
        SQL
      end

      def self.multi_assignment_sql
        <<-SQL
          SELECT DISTINCT
            staff_assignments.*,
            staff_assignments_were_visited.visited,
            COALESCE(completed_assignments.count, 0) as completed_assignments,
            completed_assignments.last_completed_at,
            (assigned_to_users.first || ' ' || assigned_to_users.last) AS assigned_to_full_name,
            (assigned_by_users.first || ' ' || assigned_by_users.last) AS assigned_by_full_name,
            COALESCE(message_history.message_count, 0) AS message_count,
            COALESCE(pre_meeting_message_history.message_count, 0) AS pre_meeting_message_count,
            COALESCE(post_meeting_message_history.message_count, 0) AS post_meeting_message_count,
            COALESCE(other_message_history.message_count, 0) AS other_message_count,
            message_history.last_messaged_at,
            COALESCE(video_views.duration, '00:00:00') AS duration,
            video_views.first_watched_at AS watched_at,
            video_views.first_viewed_at AS viewed_at,
            CASE
              WHEN video_views.first_viewed_at IS NOT NULL THEN TRUE
              ELSE FALSE
            END AS viewed,
            CASE
              WHEN video_views.first_watched_at IS NOT NULL THEN TRUE
              ELSE FALSE
            END AS watched,
            video_views.last_viewed_at,
            video_views.created_at AS registered_at,
            users.dus_id,
            users.responded_at,
            (COALESCE(users.first, '') || ' ' || COALESCE(users.last, '')) AS name,
            states.id AS state_id,
            sports.id AS sport_id,
            (COALESCE(states.abbr, '') || ' ' || COALESCE(sports.abbr_gender, '')) AS team_name,
            COALESCE(addresses.tz_offset, school_addresses.tz_offset, states.tz_offset) AS tz_offset,
            COALESCE(interests.level, 'Unknown') AS interest_level,
            COALESCE(interests.id, 0) AS interest_id
          FROM "#{usable_schema_year}".staff_assignments
          INNER JOIN users
            ON
              users.id = staff_assignments.user_id
              AND
              users.category_type IS NOT NULL
          INNER JOIN users assigned_to_users
            ON assigned_to_users.id = staff_assignments.assigned_to_id
          INNER JOIN users assigned_by_users
            ON assigned_by_users.id = staff_assignments.assigned_by_id
          LEFT JOIN (
            SELECT
              staff_assignments.user_id,
              COUNT(staff_assignments.id) as count,
              MAX(staff_assignments.completed_at) as last_completed_at
            FROM
              "#{usable_schema_year}".staff_assignments
            WHERE
                staff_assignments.reason = 'Respond'
              AND
                staff_assignments.completed = TRUE
            GROUP BY
              staff_assignments.user_id
          ) completed_assignments
            ON completed_assignments.user_id = users.id
          #{summarize_messages('message_history')}
          #{summarize_messages('pre_meeting_message_history', "user_messages.reason = 'pre-meeting'")}
          #{summarize_messages('post_meeting_message_history', "user_messages.reason = 'post-meeting'")}
          #{summarize_messages('other_message_history', "user_messages.reason NOT LIKE '%meeting'")}
          LEFT JOIN athletes
            ON (
              (athletes.id = users.category_id)
              AND
              (users.category_type = 'athletes')
            )
          LEFT JOIN coaches
            ON (
              (coaches.id = users.category_id)
              AND
              (users.category_type = 'coaches')
            )
          LEFT JOIN schools
            ON (
              schools.id = COALESCE(athletes.school_id, coaches.school_id)
            )
          LEFT JOIN addresses
            ON addresses.id = users.address_id
          LEFT JOIN addresses school_addresses
            ON school_addresses.id = schools.address_id
          LEFT JOIN states
            ON states.id = COALESCE(school_addresses.state_id, addresses.state_id)
          LEFT JOIN sports
            ON (
              sports.id = COALESCE(athletes.sport_id, coaches.sport_id)
            )
          LEFT JOIN (
            SELECT
              meeting_video_views.user_id,
              MAX(meeting_video_views.duration)::text AS duration,
              MIN(meeting_video_views.first_watched_at) AS first_watched_at,
              MIN(meeting_video_views.first_viewed_at) AS first_viewed_at,
              MAX(meeting_video_views.last_viewed_at) AS last_viewed_at,
              MIN(meeting_video_views.created_at) AS created_at
            FROM "#{usable_schema_year}".meeting_video_views
            INNER JOIN meeting_videos
              ON (
                (meeting_videos.id = meeting_video_views.video_id)
                AND
                (meeting_videos.category = 'I')
              )
            GROUP BY meeting_video_views.user_id
          ) video_views
            ON video_views.user_id = users.id
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
            staff_assignments.reason = 'Respond'
        SQL
      end
    end
  end
end
