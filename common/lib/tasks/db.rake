# encoding: utf-8
# frozen_string_literal: true

# Rake.application.options.trace = true

namespace :db do
  desc 'Drop All Attachments'
  task drop_attachments: :environment do
    ActiveStorage::Blob.delete_all
    ActiveStorage::Attachment.delete_all
  end

  task migrate_when_open: :load_config do
    puts Rails.env
    retries = 0
    begin
      Rake::Task['db:migrate'].invoke
    rescue ActiveRecord::ConcurrentMigrationError
      unless retries > 60 || ActiveRecord::ConcurrentMigrationError::RELEASE_LOCK_FAILED_MESSAGE == $!.message
        puts $!.message,
             "waiting: #{sleep_for = (retries * (retries += 1) / 2)} seconds"

        sleep sleep_for

        [
          'db:migrate',
          'db:set_to_public',
          'db:set_to_default',
          'db:views:up:before',
          'db:views:up:after'
        ].map {|t| Rake::Task[t].reenable}

        retry
      else
        raise
      end
    end
  end

  task :set_to_public do
    set_db_year "public"
  end

  task :set_to_default do
    set_db_default_year
  end

  namespace :views do
    namespace :up do
      task before: :environment do
        require 'db/views'
        Views.before(false)
      end

      task after: :environment do
        require 'db/views'
        Views.after
      end
    end

    namespace :down do
      task before: :environment do
        require 'db/views'
        Views.before(true)
      end

      task after: :environment do
        require 'db/views'
        Views.after
      end
    end

    task rebuild: :environment do
      require 'db/views'
      Views.before(true)
      Views.after
    end
  end
end

Rake::Task['db:migrate'].enhance(['db:views:up:before', 'db:set_to_public']) do
  Rake::Task['db:set_to_default'].invoke
  Rake::Task['db:views:up:after'].invoke
end

Rake::Task['db:rollback'].enhance(['db:views:down:before', 'db:set_to_public']) do
  Rake::Task['db:set_to_default'].invoke
  Rake::Task['db:views:down:after'].invoke
end
