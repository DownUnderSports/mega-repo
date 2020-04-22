# encoding: utf-8
# frozen_string_literal: true

namespace :assets do
  desc 'Normalize address time zones'
  task upload_to_s3: :environment do
    if ENV['S3_ASSET_PREFIX'] && ENV['S3_ASSET_PREFIX'][0]
      S3AssetManager.upload_folder(Rails.root.join('client', 'build'), prefix: ENV['S3_ASSET_PREFIX'])
      if ENV['SERVICE_WORKER_APP_FOLDER'] && ENV['SERVICE_WORKER_APP_FOLDER'][0]
        S3AssetManager.upload_folder(Rails.root.join(ENV['SERVICE_WORKER_APP_FOLDER'], 'build'), prefix: "#{ENV['S3_ASSET_PREFIX']}/service_worker")
      end
    end
  end
end
