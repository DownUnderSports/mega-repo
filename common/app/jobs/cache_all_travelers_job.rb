class CacheAllTravelersJob < ApplicationJob
  queue_as :route_cache

  def perform
    delete_unnecessary

    base_path = local_host

    Traveler.active do |t|
      next if t.balance <= 0 || Rails.redis.keys("*payment.*#{t.user.__send__(:cache_match_str)}")

      [
        t.user.dus_id,
        t.user[:dus_id]
      ].each do |v|
        CacheRouteJob.perform_later("#{base_path}/#{v}")
        CacheRouteJob.perform_later("#{base_path}/payment/#{v}")
      end
    end
  end

  private
    def delete_unnecessary
      queue = Sidekiq::Queue.new("route_cache")
      queue.each do |job|
        job.delete if job.class == "CacheAllTravelersJob"
      end
    end
end
