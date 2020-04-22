class CacheRouteJob < ApplicationJob
  queue_as :route_cache

  def perform(url)
    require 'open-uri'
    delete_unnecessary(url)

    og_url = url
    raise "Nothing Specified" unless og_url.present?

    url = "#{url}#{(url.to_s =~ /\?/) ? '&' : '?'}rendering_no_cache=1" unless url.to_s =~ /rendering_no_cache/

    response = open "#{ENV.fetch("SSR_RENDERER_URL") { 'http://lvh.me:5000' }}/render?url=#{ERB::Util.url_encode(url)}"
    result = response.read
    k, t = url_cache_keys(og_url)
    Rails.redis.mset(k, result, t, Time.zone.now.to_s)
  rescue
    puts "ERROR: #{$!.message}"
    puts $!.backtrace.first(10)
    begin
      Rails.redis.del(url_cache_keys(og_url))
    rescue
    end
  end

  private
    def delete_unnecessary(url)
      queue = Sidekiq::Queue.new("route_cache")
      queue.each do |job|
        args = job.args.first['arguments'] || [] rescue []
        job.delete if args.first == url
      end
    end
end
