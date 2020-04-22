# encoding: utf-8
# frozen_string_literal: true

module Views
  module Assignments
    module UnassignedResponds
      def self.table_name
        "#{usable_schema_year}.assignments_unassigned_responds_view"
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

      def self.sql
        <<-SQL
          SELECT DISTINCT
            users.*,
            COALESCE(video_views.duration, '00:00:00') AS duration,
            video_views.first_watched_at AS watched_at,
            video_views.first_viewed_at AS viewed_at,
            video_views.last_viewed_at AS last_viewed_at,
            video_views.created_at AS registered_at,
            CASE
              WHEN video_views.first_viewed_at IS NOT NULL THEN TRUE
              ELSE FALSE
            END AS viewed,
            CASE
              WHEN video_views.first_watched_at IS NOT NULL THEN TRUE
              ELSE FALSE
            END AS watched,
            states.abbr AS state_abbr,
            sports.abbr AS sport_abbr,
            COALESCE(addresses.tz_offset, school_addresses.tz_offset, states.tz_offset) tz_offset
          FROM "users"
          INNER JOIN interests
            ON (
              (interests.id = users.interest_id)
              AND
              (interests.contactable = TRUE)
            )
          INNER JOIN athletes
            ON (
              (athletes.id = users.category_id)
              AND
              (users.category_type = 'athletes')
            )
          LEFT JOIN schools
            ON schools.id = athletes.school_id
          LEFT JOIN addresses
            ON addresses.id = users.address_id
          LEFT JOIN addresses school_addresses
            ON school_addresses.id = schools.address_id
          LEFT JOIN states
            ON states.id = COALESCE(school_addresses.state_id, addresses.state_id)
          LEFT JOIN sports
            ON sports.id = athletes.sport_id
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
          WHERE
            (
                users.responded_at IS NOT NULL
              OR
                users.interest_id IN (
                  SELECT
                    id
                  FROM public.interests sub_interests
                  WHERE
                    sub_interests.contactable = TRUE
                    AND
                    (NOT ( sub_interests.level = 'Unknown' ))
                )
              OR
                (
                  EXISTS (
                    SELECT
                      1
                    FROM
                      "#{usable_schema_year}".user_messages
                    WHERE
                        user_messages.user_id = users.id
                      AND
                        user_messages.message = 'Marked for infokit pre-mail'
                  )
                )
            )
            AND
              users.category_type = 'athletes'
            AND
              (
                NOT (
                  EXISTS (
                    SELECT
                      1
                    FROM
                      "#{usable_schema_year}".staff_assignments
                    WHERE
                        staff_assignments.user_id = users.id
                      AND
                        staff_assignments.reason = 'Respond'
                  )
                )
              )
            AND
              (
                NOT (
                  EXISTS (
                    SELECT
                      1
                    FROM
                      "#{usable_schema_year}".travelers
                    WHERE
                        travelers.user_id = users.id
                  )
                )
              )
          ORDER BY users.id ASC
        SQL
      end

      def self.multi_assignment_sql
        <<-SQL
          SELECT DISTINCT
            users.*,
            COALESCE(completed_assignments.count, 0) as completed_assignments,
            completed_assignments.last_completed_at,
            COALESCE(video_views.duration, '00:00:00') AS duration,
            video_views.first_watched_at AS watched_at,
            video_views.first_viewed_at AS viewed_at,
            video_views.last_viewed_at AS last_viewed_at,
            video_views.created_at AS registered_at,
            CASE
              WHEN video_views.first_viewed_at IS NOT NULL THEN TRUE
              ELSE FALSE
            END AS viewed,
            CASE
              WHEN video_views.first_watched_at IS NOT NULL THEN TRUE
              ELSE FALSE
            END AS watched,
            states.abbr AS state_abbr,
            sports.abbr AS sport_abbr,
            COALESCE(addresses.tz_offset, school_addresses.tz_offset, states.tz_offset) tz_offset
          FROM "users"
          INNER JOIN interests
            ON (
              (interests.id = users.interest_id)
              AND
              (interests.contactable = TRUE)
            )
          INNER JOIN athletes
            ON (
              (athletes.id = users.category_id)
              AND
              (users.category_type = 'athletes')
            )
          LEFT JOIN schools
            ON schools.id = athletes.school_id
          LEFT JOIN addresses
            ON addresses.id = users.address_id
          LEFT JOIN addresses school_addresses
            ON school_addresses.id = schools.address_id
          LEFT JOIN states
            ON states.id = COALESCE(school_addresses.state_id, addresses.state_id)
          LEFT JOIN sports
            ON sports.id = athletes.sport_id
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
          LEFT JOIN (
            SELECT
              staff_assignments.user_id,
              COUNT(id) as count,
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
          WHERE
            (
                users.responded_at IS NOT NULL
              OR
                users.interest_id IN (
                  SELECT
                    id
                  FROM public.interests sub_interests
                  WHERE
                    sub_interests.contactable = TRUE
                    AND
                    (NOT ( sub_interests.level = 'Unknown' ))
                )
            )
            AND
              users.category_type = 'athletes'
            AND
              (
                  completed_assignments.count IS NULL
                OR
                  completed_assignments.count < 3
              )
            AND
              (
                NOT (
                  EXISTS (
                    SELECT
                      1
                    FROM
                      "#{usable_schema_year}".staff_assignments
                    WHERE
                        staff_assignments.user_id = users.id
                      AND
                        staff_assignments.reason = 'Respond'
                      AND
                        (
                            staff_assignments.completed = false
                          OR
                            (
                                staff_assignments.follow_up_date IS NOT NULL
                              AND
                                staff_assignments.follow_up_date > CURRENT_DATE
                            )
                        )
                  )
                )
              )
            AND
              (
                NOT (
                  EXISTS (
                    SELECT
                      1
                    FROM
                      "#{usable_schema_year}".travelers
                    WHERE
                        travelers.user_id = users.id
                  )
                )
              )
          ORDER BY users.id ASC
        SQL
      end
    end
  end
end
