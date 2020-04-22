# encoding: utf-8
# frozen_string_literal: true

namespace :heroku do
  namespace :ruby do
    desc '"Postbuild" tasks needed only on heroku'
    task postbuild: :environment do
      Rake::Task['cache:set_version'].invoke
      Rake::Task['gpg:setup'].invoke
      Rake::Task['cache:pages:clear_invalid'].invoke
      Rake::Task['auth:set_production'].invoke
      Rake::Task['assets:upload_to_s3'].invoke
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
