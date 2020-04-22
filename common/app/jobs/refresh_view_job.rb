class RefreshViewJob < ApplicationJob
  queue_as :default

  def perform(name, concurrently: true)
    concurrently = Boolean.parse(concurrently)

    begin
      sq = Sidekiq::Queue.new("default")
      sq.each do |job|
        if same_job? job, name, concurrently
          job.delete
        end
      end
    rescue
    end

    ViewTracker.refresh_view(name, concurrently: concurrently, async: false)
  end

  def same_job?(job, name, concurrently)
    args = job.args[0] || {}

    (args['job_class'] == 'RefreshViewJob') &&
    args['arguments'] &&
    (args['arguments'][0] == name) &&
    (Boolean.parse((args['arguments'][1] || {})['concurrently']) == concurrently)
  end
end
