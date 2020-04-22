# encoding: utf-8
# frozen_string_literal: true

namespace :cache do
  namespace :pages do
    desc 'Clear cached pages from previous versions'
    task clear_invalid: :environment do
      keys =
        Rails.
          redis.
          keys('page_cache.*').
          filter {|k| k.to_s !~ /#{DownUnderSports::VERSION}/ }

      Rails.redis.del(*keys) if keys.present?
    end
  end

  task set_version: :environment do
    # `#{Rails.root.join('bin', 'version')}`
    #
    # DownUnderSports.__send__ :remove_const, :VERSION
    #
    # require_dependency Rails.root.join('config/version')
  end
end
