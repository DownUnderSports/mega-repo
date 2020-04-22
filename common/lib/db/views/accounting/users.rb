# encoding: utf-8
# frozen_string_literal: true

module Views
  module Accounting
    module Users
      def self.table_name
        "#{usable_schema_year}.accounting_users_view"
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
        migration.add_index(table_name, :dus_id, unique: true)
        migration.add_index(table_name, :first)
        migration.add_index(table_name, :last)
        migration.add_index(table_name, :state_abbr)
        migration.add_index(table_name, :sport_abbr)
      end

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

      def self.sql
        User::Views::Index.
          joins(
            <<-SQL
              LEFT JOIN (
                SELECT
                  traveler_id,
                  SUM(amount) AS amount
                FROM payment_items
                WHERE traveler_id IS NOT NULL
                GROUP BY traveler_id
              ) payment_summaries
              ON payment_summaries.traveler_id = users_index_view.traveler_id
              LEFT JOIN (
                SELECT
                  traveler_id,
                  SUM(amount) AS amount
                FROM traveler_debits
                WHERE traveler_id IS NOT NULL
                GROUP BY traveler_id
              ) debit_summaries
              ON debit_summaries.traveler_id = users_index_view.traveler_id
              LEFT JOIN (
                SELECT
                  traveler_id,
                  SUM(amount) AS amount
                FROM traveler_credits
                WHERE traveler_id IS NOT NULL
                GROUP BY traveler_id
              ) credit_summaries
              ON credit_summaries.traveler_id = users_index_view.traveler_id
            SQL
          ).
          select(
            "#{User::Views::Index.table_name}.*",
            'COALESCE(payment_summaries.amount, 0)::money_integer AS total_paid',
            'COALESCE(debit_summaries.amount, 0)::money_integer AS total_debited',
            'COALESCE(credit_summaries.amount, 0)::money_integer AS total_credited',
            '(COALESCE(debit_summaries.amount, 0) - COALESCE(credit_summaries.amount, 0))::money_integer AS total_charges',
            '(COALESCE(debit_summaries.amount, 0) - (COALESCE(payment_summaries.amount, 0) + COALESCE(credit_summaries.amount, 0)))::money_integer AS current_balance'
          ).to_sql
      end
    end
  end
end
