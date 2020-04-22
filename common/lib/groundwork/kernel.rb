module Kernel
  private
    def current_year
      value = "#{ENV['CURRENT_YEAR'].to_s}".strip
      value.empty? ? nil : value
    end

    def current_schema_year
      current_year ? "year_#{current_year}" : "public"
    end

    def usable_schema_year
      return 'public' unless current_year

      result = ActiveRecord::Base.connection.execute <<-SQL
        SELECT EXISTS (
          SELECT 1
          FROM pg_namespace
          WHERE nspname = '#{current_schema_year}'
        )
      SQL

      result.first['exists'] ? current_schema_year : 'public'
    rescue Exception
      'public'
    end
end
