# encoding: utf-8
# frozen_string_literal: true

namespace :heroku do
  namespace :ruby do
    desc '"Postbuild" tasks needed only on heroku'
    task postbuild: :environment do
      [
        'cache:set_version',
        'gpg:setup',
        'cache:pages:clear_invalid',
        'auth:set_production',
        'assets:upload_to_s3',
      ].each do |task_name|
        Rake::Task[task_name].invoke
      end
      # CacheAllTravelersJob.set(wait_until: 5.minutes.from_now).perform_later
      ViewTracker.delete_all

    end
  end

  desc 'Send daily reports using heroku scheduler'
  task daily: :environment do
    [
      'report:responds',
    ].each do |task_name|
      Rake::Task[task_name].invoke
    rescue
      puts $!.message
      puts $!.backtrace
    end

    if Time.zone.now.wday == 0
      [
        "report:cleanup"
      ].each do |task_name|
        Rake::Task[task_name].invoke
      end
    end

    ViewTracker.delete_all
  end

  desc 'Run nightly normalization tasks using heroku scheduler'
  task nightly: :environment do
    [
      'assignments:reset_visits',
      'uploads:clear_invalid',
      'travelers:set_details'
    ].each do |task_name|
      Rake::Task[task_name].invoke
    rescue
      puts $!.message
      puts $!.backtrace
    end
  end

  desc 'Run 11:00 daily tasks using heroku scheduler'
  task morning: :environment do
    # [
    #   'assignments:send_summary',
    # ].each do |task_name|
    #   Rake::Task[task_name].invoke
    # rescue
    #   puts $!.message
    #   puts $!.backtrace
    # end
  end

  desc 'Run 16:30 daily tasks using heroku scheduler'
  task afternoon: :environment do
    # [
    #   'assignments:send_summary',
    # ].each do |task_name|
    #   Rake::Task[task_name].invoke
    # rescue
    #   puts $!.message
    #   puts $!.backtrace
    # end
  end
end

Rake::Task['assets:precompile'].enhance do
  Rake::Task['heroku:ruby:postbuild'].invoke
end
