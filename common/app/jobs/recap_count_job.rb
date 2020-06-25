class RecapCountJob < ApplicationJob
  queue_as :default

  def perform(id)
    User::Recap.find_by(id: id)&.__send__(:set_counts)
  end
end
