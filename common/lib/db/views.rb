module Views
  @@did_run = false

  def self.require_all
    require 'db/views/accounting/remit_forms'
    require 'db/views/accounting/users'
    require 'db/views/assignments/travelers'
    require 'db/views/assignments/unassigned_travelers'
    require 'db/views/assignments/responds'
    require 'db/views/assignments/unassigned_responds'
    require 'db/views/participants/map'
    require 'db/views/users/index'
  end

  def self.destroy_all(migration)
    require_all

    Views::Accounting::RemitForms.destroy(migration)
    Views::Accounting::Users.destroy(migration)
    Views::Assignments::Travelers.destroy(migration)
    Views::Assignments::UnassignedTravelers.destroy(migration)
    Views::Assignments::Responds.destroy(migration)
    Views::Assignments::UnassignedResponds.destroy(migration)
    Views::Participants::Map.destroy(migration)
    Views::Users::Index.destroy(migration)
  end

  def self.create_all(migration)
    require_all

    Views::Users::Index.create(migration)
    Views::Participants::Map.create(migration)
    Views::Assignments::UnassignedResponds.create(migration)
    Views::Assignments::Responds.create(migration)
    Views::Assignments::UnassignedTravelers.create(migration)
    Views::Assignments::Travelers.create(migration)
    Views::Accounting::Users.create(migration)
    Views::Accounting::RemitForms.create(migration)
  end

  def self.before(is_down = false)
    initial_env = current_year
    begin
      @@did_run = false
      if is_down || ActiveRecord::Base.connection.migration_context.needs_migration?
        @@did_run = true
        if schema_exists? 'year_2019'
          %w[
            2019
            2020
            2021
          ].each do |year|
            if schema_exists? "year_#{year}"
              ENV['CURRENT_YEAR'] = year
              reset_cached_usable_schema_year

              with_year(year) do
                raise usable_schema_year unless usable_schema_year =~ /#{year}/
                EnsuredMigrator.new(:down, [
                  ViewsMigration.new(nil, EnsuredMigrator.current_version)
                ]).migrate
              end
            end
          end
        else
          EnsuredMigrator.new(:down, [
            ViewsMigration.new(nil, EnsuredMigrator.current_version)
          ]).migrate
        end
      end
    ensure
      ENV['CURRENT_YEAR'] = initial_env
      reset_cached_usable_schema_year
    end
  end

  def self.after
    initial_env = current_year
    begin
      if @@did_run
        @@did_run = false
        if schema_exists? 'year_2019'
          %w[
            2019
            2020
            2021
          ].each do |year|
            if schema_exists? "year_#{year}"
              ENV['CURRENT_YEAR'] = year
              reset_cached_usable_schema_year

              with_year(year) do
                raise usable_schema_year unless usable_schema_year =~ /#{year}/
                EnsuredMigrator.new(:up, [
                  ViewsMigration.new(nil, EnsuredMigrator.current_version + 1)
                ]).migrate
              end
            end
          end
        else
          EnsuredMigrator.new(:up, [
            ViewsMigration.new(nil, EnsuredMigrator.current_version + 1)
          ]).migrate
        end
      end
    ensure
      ENV['CURRENT_YEAR'] = initial_env
      reset_cached_usable_schema_year
    end
  end

  def self.schema_exists? value
    ActiveRecord::Base.connection.schema_exists? value
  end

  def recreate
    initial_env = current_year
    begin
      [
        2019,
        2020
      ].each do |year|
        if schema_exists? "year_#{year}"
          ENV['CURRENT_YEAR'] = year
          reset_cached_usable_schema_year

          with_year(year) do
            EnsuredMigrator.new(:up, [
              ViewsMigration.new(nil, EnsuredMigrator.current_version + 1)
            ]).migrate
          end
        end
      end
    ensure
      ENV['CURRENT_YEAR'] = initial_env
      reset_cached_usable_schema_year
    end
  end

  class EnsuredMigrator < ActiveRecord::Migrator
    def runnable
      migrations[start..finish]
    end

    private
      def record_version_state_after_migrating(version)
        true
      end
  end

  class ViewsMigration < ActiveRecord::Migration[5.2]
    def down
      Views.destroy_all(self)
    end

    def up
      Views.create_all(self)
    end
  end

end
