# encoding: utf-8
# frozen_string_literal: true

module Views
  module Participants
    module Map
      def self.table_name
        "#{usable_schema_year}.participants_map_view"
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
        migration.add_index(table_name, :state_id)
      end

      def self.table_exists?
        result = ActiveRecord::Base.connection.execute <<-SQL
          SELECT EXISTS (
            SELECT 1
            FROM   pg_catalog.pg_class c
            JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
            WHERE  c.relname = 'participants'
            AND    c.relkind = 'r'
          )
        SQL

        result.first['exists']
      rescue Exception
        false
      end

      def self.sql
        Participant.
          where(category: 'athlete').
          joins(:state).
          select(:id, :name, :school, 'states.full AS state', :state_id).
          to_sql
      end
    end
  end
end
