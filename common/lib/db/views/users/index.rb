# encoding: utf-8
# frozen_string_literal: true

module Views
  module Users
    module Index
      def self.table_name
        "#{usable_schema_year}.users_index_view"
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

        self.indexes migration
      end

      def self.indexes(migration)
        migration.add_index(table_name, :id, unique: true)
        migration.add_index(table_name, :dus_id, unique: true)
        migration.add_index(table_name, :difficulty)
        migration.add_index(table_name, :status)
        migration.add_index(table_name, :can_transfer)
        migration.add_index(table_name, :can_compete)
        migration.add_index(table_name, :joined_at)
        migration.add_index(table_name, :cancel_date)
        migration.add_index(table_name, :traveler_id)
        migration.add_index(table_name, :state_abbr)
        migration.add_index(table_name, :sport_abbr)
        migration.add_index(table_name, :sport_id)
        migration.add_index(table_name, :state_id)
        migration.add_index(table_name, :responded_at)
        migration.add_index(table_name, :grad)
      end

      # rubocop:disable Lint/RescueException
      def self.table_exists?
        result = ActiveRecord::Base.connection.execute <<-SQL
          SELECT EXISTS (
            SELECT 1
            FROM   pg_catalog.pg_class c
            JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE  c.relname = 'payment_items'
            AND    c.relkind = 'r'
          )
        SQL

        result.first['exists']
      rescue Exception
        false
      end
      # rubocop:enable Lint/RescueException

      def self.sql
        Official.reset_column_information
        updated_official = Official.column_names.include? 'sport_id'

        official_query = !updated_official ?
          (
            <<-SQL
              LEFT JOIN "#{usable_schema_year}".teams official_team
                ON (
                  official_team.id = officials.team_id

                )
            SQL
          ) : ''

        User.reset_column_information
        visible_until_year = current_year && User.column_names.include?('visible_until_year')

        visible_query = visible_until_year ?
          (
            <<-SQL
              WHERE
                ( users.visible_until_year > #{current_year} )
            SQL
          ) : ''

        <<-SQL
          SELECT DISTINCT
            users.*,
            user_transfer_expectations.difficulty,
            user_transfer_expectations.status,
            user_transfer_expectations.can_transfer,
            user_transfer_expectations.can_compete,
            travelers.id AS traveler_id,
            travelers.joined_at,
            travelers.cancel_date,
            coaches.id AS coach_id,
            athletes.id AS athlete_id,
            athletes.grad AS grad,
            states.id AS state_id,
            states.abbr AS state_abbr,
            sports.id AS sport_id,
            sports.abbr_gender AS sport_abbr,
            COALESCE(travelers.departing_date, calculated_team.departing_date) AS departing_date,
            schools.id AS school_id,
            deferrals.deferral,
            invite_rules.grad_year AS max_grad_year,
            invite_rules.invitable,
            invite_rules.certifiable
          FROM users
          LEFT OUTER JOIN (
            SELECT
              id,
              (
                EXISTS (
                  SELECT
                    1
                  FROM
                    user_messages
                  WHERE
                      (user_messages.type IN ('User::Note'))
                    AND
                      (user_messages.user_id = deferral_check.id)
                    AND
                      (message like 'Deferral to 20__')
                )
              ) AS deferral
            FROM users deferral_check
          ) deferrals ON (deferrals.id = users.id)
          LEFT OUTER JOIN (
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
          ) travelers ON (travelers.user_id = users.id)
          LEFT JOIN "#{usable_schema_year}".user_transfer_expectations
            ON user_transfer_expectations.user_id = users.id
          LEFT JOIN "#{usable_schema_year}".teams
            ON teams.id = travelers.team_id
          LEFT JOIN (
            SELECT
              sub_users.id user_id,
              related_user_id
            FROM
              users sub_users
            LEFT JOIN user_relations related_user_join
              ON (
                related_user_join.id = (
                  SELECT
                    user_relations.id
                  FROM user_relations
                  INNER JOIN users single_users
                  ON single_users.id = user_relations.related_user_id
                  WHERE (
                    user_id = sub_users.id
                    AND
                    single_users.category_type IN ('athletes', 'coaches')
                  )
                  LIMIT 1
                )
              )
            ) related_user_row
              ON (
                (users.category_type IS NULL)
                AND
                (related_user_row.user_id = users.id)
              )
          LEFT JOIN users main_user
            ON (main_user.id = related_user_row.related_user_id)
          LEFT JOIN athletes
            ON (
              (athletes.id = COALESCE(users.category_id, main_user.category_id))
              AND
              (COALESCE(users.category_type, main_user.category_type) = 'athletes')
            )
          LEFT JOIN coaches
            ON (
              (coaches.id = COALESCE(users.category_id, main_user.category_id))
              AND
              (COALESCE(users.category_type, main_user.category_type) = 'coaches')
            )
          LEFT JOIN officials
            ON (
              (officials.id = COALESCE(users.category_id, main_user.category_id))
              AND
              (COALESCE(users.category_type, main_user.category_type) = 'officials')
            )
          LEFT JOIN schools
            ON (
              schools.id = COALESCE(athletes.school_id, coaches.school_id)
            )
          LEFT JOIN addresses
            ON (
              addresses.id = COALESCE(schools.address_id, users.address_id)
            )
          #{official_query}
          LEFT JOIN states
            ON states.id = COALESCE(teams.state_id, #{updated_official ? "officials.state_id" : "official_team.state_id"}, addresses.state_id)
          LEFT JOIN sports
            ON (
              sports.id = COALESCE(teams.sport_id, #{updated_official ? "officials.sport_id" : "official_team.sport_id"}, athletes.sport_id, coaches.sport_id)
            )
          LEFT JOIN "#{usable_schema_year}".teams calculated_team
            ON (
              (calculated_team.sport_id = sports.id)
              AND
              (calculated_team.state_id = states.id)
            )
          LEFT JOIN invite_rules
            ON (
              (invite_rules.sport_id = sports.id)
              AND
              (invite_rules.state_id = states.id)
            )
          #{visible_query}
          ORDER BY users.id ASC
        SQL
      end
    end
  end
end
