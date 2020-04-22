# encoding: utf-8
# frozen_string_literal: true

module Views
  module Assignments
    module UnassignedTravelers
      def self.table_name
        "#{usable_schema_year}.assignments_unassigned_travelers_view"
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

        migration.add_index(table_name, :id, unique: true, name: "unassigned_travelers_view_id_idx")
        migration.add_index(table_name, [ :state_abbr, :sport_abbr ], name: "unassigned_travelers_view_state_and_sport_idx")
        migration.add_index(table_name, [ :sport_abbr, :state_abbr ], name: "unassigned_travelers_view_sport_and_state_idx")
        migration.add_index(table_name, :joined_at, name: "unassigned_travelers_view_joined_at_idx")
        migration.add_index(table_name, :cancel_date, name: "unassigned_travelers_view_cancel_date_idx")
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
            travelers.joined_at,
            travelers.cancel_date,
            states.abbr AS state_abbr,
            sports.abbr AS sport_abbr
          FROM "users"
          INNER JOIN interests
            ON (
              (interests.id = users.interest_id)
              AND
              (interests.contactable = TRUE)
            )
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
          WHERE NOT EXISTS
            (
              SELECT
                1
              FROM
                "#{usable_schema_year}".staff_assignments
              WHERE
                  staff_assignments.user_id = users.id
                AND
                  staff_assignments.reason = 'Traveler'
            )
          ORDER BY users.id ASC
        SQL
      end
    end
  end
end
