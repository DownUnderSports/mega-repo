# encoding: utf-8
# frozen_string_literal: true

module Views
  module Accounting
    module RemitForms
      def self.table_name
        "#{usable_schema_year}.accounting_remit_forms_view"
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

        migration.add_index(table_name, :remit_number, unique: true, name: :"#{usable_schema_year}_remit_forms_view_on_remit_number")
        migration.add_index(table_name, :positive_amount, name: :"#{usable_schema_year}_remit_forms_view_on_positive_amount")
        migration.add_index(table_name, :negative_amount, name: :"#{usable_schema_year}_remit_forms_view_on_negative_amount")
        migration.add_index(table_name, :net_amount, name: :"#{usable_schema_year}_remit_forms_view_on_net_amount")
        migration.add_index(table_name, :successful_amount, name: :"#{usable_schema_year}_remit_forms_view_on_successful_amount")
        migration.add_index(table_name, :failed_amount, name: :"#{usable_schema_year}_remit_forms_view_on_failed_amount")
        migration.add_index(table_name, :recorded, name: :"#{usable_schema_year}_remit_forms_view_on_recorded")
        migration.add_index(table_name, :reconciled, name: :"#{usable_schema_year}_remit_forms_view_on_reconciled")
      end

      def self.table_exists?
        result = ActiveRecord::Base.connection.execute <<-SQL
          SELECT EXISTS (
            SELECT 1
            FROM   pg_catalog.pg_class c
            JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE  c.relname = 'payment_remittances'
            AND    c.relkind = 'r'
          )
        SQL

        result.first['exists']
      rescue Exception
        false
      end

      def self.sql
        <<-SQL
          SELECT
            payment_groups.remit_number,
            payment_groups.positive_amount,
            payment_groups.negative_amount,
            payment_groups.net_amount,
            payment_results.successful_amount,
            payment_results.failed_amount,
            COALESCE(payment_remittances.recorded, FALSE) as recorded,
            COALESCE(payment_remittances.reconciled, FALSE) as reconciled
          FROM
            (
              SELECT
                remit_number,
                COALESCE(SUM(positive_items.total), 0)::integer AS positive_amount,
                COALESCE(SUM(negative_items.total), 0)::integer AS negative_amount,
                (SUM(COALESCE(positive_items.total, 0))::integer + SUM(COALESCE(negative_items.total, 0))::integer)::integer AS net_amount
              FROM
                payments
              LEFT JOIN
                (
                  SELECT
                    payment_id,
                    SUM(amount) AS total
                  FROM
                    payment_items
                  WHERE
                    amount > 0
                  GROUP BY
                    payment_id
                ) positive_items
              ON positive_items.payment_id = payments.id
              LEFT JOIN
                (
                  SELECT
                    payment_id,
                    SUM(amount) AS total
                  FROM
                    payment_items
                  WHERE
                    amount < 0
                  GROUP BY
                    payment_id
                ) negative_items
              ON negative_items.payment_id = payments.id
              WHERE
                payments.successful = 't'
              GROUP BY remit_number
            ) payment_groups
          LEFT JOIN
            (
              SELECT
                remit_number,
                SUM(
                  CASE WHEN payments.successful
                  THEN COALESCE(amount, 0)
                  ELSE 0
                  END
                ) AS successful_amount,
                SUM(
                  CASE WHEN payments.successful
                  THEN 0
                  ELSE COALESCE(amount, 0)
                  END
                ) AS failed_amount
              FROM
                payments
              GROUP BY remit_number
            ) payment_results
            ON payment_results.remit_number = payment_groups.remit_number
          LEFT JOIN
            payment_remittances
            ON payment_remittances.remit_number = payment_groups.remit_number
        SQL
      end
    end
  end
end
