ActiveSupport.on_load(:active_record) do
  module ActiveRecord
    class Migration
      def audit_yearly_table(table_name, *args)
        %w[
          year_2019
          year_2020
          year_2021
        ].each do |year|
          audit_table("#{year}.#{table_name}", *args)
        end
      end

      def change_yearly_table(table_name, options, &block)
        %w[
          public
          year_2019
          year_2020
          year_2021
        ].each do |schema|
          change_table("#{schema}.#{table_name}", options) do |t|
            block.call(t, schema)
          end
        end
      end

      def drop_yearly_table(table_name)
        %w[
          year_2021
          year_2020
          year_2019
          public
        ].each do |schema|
          drop_table("#{schema}.#{table_name}")
        end
      end

      def set_table_to_yearly(table_name:, foreign_keys: [], &block)
        reversible do |d|
          d.up do
            table_id = (
              execute <<-SQL
                SELECT c.oid,
                  n.nspname,
                  c.relname
                FROM pg_catalog.pg_class c
                  LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
                WHERE c.relname = '#{table_name}'
                  AND n.nspname = 'public'
                ORDER BY 2, 3;
              SQL
            ).first

            table_indexes = (
              execute <<-SQL
                SELECT
                  c2.relname,
                  i.indisprimary,
                  i.indisunique,
                  i.indisclustered,
                  i.indisvalid,
                  pg_catalog.pg_get_indexdef(i.indexrelid, 0, true),
                  pg_catalog.pg_get_constraintdef(con.oid, true),
                  contype,
                  condeferrable,
                  condeferred,
                  i.indisreplident,
                  c2.reltablespace
                FROM
                  pg_catalog.pg_class c,
                  pg_catalog.pg_class c2,
                  pg_catalog.pg_index i
                LEFT JOIN
                  pg_catalog.pg_constraint con
                  ON (conrelid = i.indrelid AND conindid = i.indexrelid AND contype IN ('p','u','x'))
                WHERE c.oid = '#{table_id['oid']}' AND c.oid = i.indrelid AND i.indexrelid = c2.oid
                ORDER BY i.indisprimary DESC, i.indisunique DESC, c2.relname;
              SQL
            ).to_a

            constraint = ""

            table_indexes.dup.each do |idx|
              if idx['pg_get_constraintdef'].present? && idx['contype'] == 'p'
                constraint = ",\nCONSTRAINT year_YEAR_#{table_name}_pkey #{idx['pg_get_constraintdef']}"
                table_indexes.delete_at(table_indexes.index(idx))
              end
            end

            [
              2019,
              2020,
              2021
            ].each do |year|
              execute <<-SQL
                CREATE TABLE IF NOT EXISTS "year_#{year}"."#{table_name}" (
                  operating_year INTEGER DEFAULT #{year} CHECK (operating_year = #{year})#{constraint.sub('year_YEAR', "year_#{year}")}
                ) INHERITS ("public"."#{table_name}");
              SQL

              (foreign_keys || []).each do |fk_data|
                from_col,
                to_table,
                to_schema,
                to_col =
                  fk_data[:from_col].to_s,
                  fk_data[:to_table].to_s,
                  (fk_data[:to_schema] || 'public').to_s,
                  (fk_data[:to_col] || 'id').to_s

                raise "Invalid Options for Foreign Key: #{fk_data}" unless [ from_col, to_table, to_schema, to_col ].all?(&:present?)

                identifier = Digest::SHA256.hexdigest("#{year}_#{table_name}_#{from_col}").first(10)

                execute <<-SQL
                  ALTER TABLE "year_#{year}"."#{table_name}"
                  ADD CONSTRAINT fk_rails_#{identifier}
                  FOREIGN KEY (#{from_col})
                  REFERENCES #{to_schema.sub('YEAR', year.to_s)}.#{to_table}(#{to_col})
                  DEFERRABLE INITIALLY IMMEDIATE
                SQL
              end

              table_indexes.each do |idx|
                execute idx["pg_get_indexdef"].sub(/ON\s+#{table_name}/, "ON year_#{year}.#{table_name}")
              end

              if block_given?
                change_table "year_#{year}.#{table_name}" do |t|
                  block.call(t)
                end
              end
            end
          end

          d.down do
            [
              2019,
              2020,
              2021
            ].each do |year|
              execute %Q(DROP TABLE IF EXISTS "year_#{year}"."#{table_name}" CASCADE;)
            end
          end
        end
      end
    end
  end
end
