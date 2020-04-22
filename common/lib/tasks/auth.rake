# encoding: utf-8
# frozen_string_literal: true

namespace :auth do
  desc 'Set Auth Url to Production'
  task set_production: :environment do
    path = Rails.root.join('aus', 'build', 'index.html')
    if File.exist?(path)
      txt = File.read(path)
      txt.gsub!(/http\:/, 'https:')
      txt.gsub!(/(localhost|lvh.me|127.0.0.1)\:\d+/, "downundersports.com")
      File.open(path, 'w') {|f| f << txt}
    end
  end
end
