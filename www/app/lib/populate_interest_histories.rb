module PopulateInterestHistories
  def self.run
    logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = Rails.logger.clone
    ActiveRecord::Base.logger.level = Logger::WARN
    t = Time.zone.now

    time_out_blocker = ->(progress) do
      if Time.zone.now - t > 5.minutes
        puts "\nProgress: #{progress} #{Time.zone.now.strftime('%Y-%M-%d %H:%M:%S.%N')}\n"
        t = Time.zone.now
      end
    end

    open_tryout_added = Time.find_zone("UTC").parse('2020-02-06 02:38:21.722169').in_time_zone
    removed_restricted = Time.find_zone("UTC").parse('2019-09-26 01:15:45.392626').in_time_zone

    q = User::LoggedAction.where(action: "I").or(
      User::LoggedAction.where("changed_fields ? 'interest_id'")
    ).
    where(%Q(EXISTS (SELECT 1 FROM "users" WHERE ("auditing"."logged_actions_users"."row_id" = "users"."id")))).
    order(:action_tstamp_tx, :event_id);

    size = q.size.to_s
    i = 0

    puts "\nSTART: #{Time.zone.now.strftime('%Y-%M-%d %H:%M:%S.%N')}\n"

    q.retrieve_batch_values_async(of: 5000, preserve_order: true) do |action|
      str = "#{(i += 1).to_s.rjust(size.size, "0")}/#{size}"
      time_out_blocker.call(str)
      print "#{str}\r"
      # GC.start if i % 100000 == 0

      if action.action_tstamp_tx == removed_restricted
        action = q.where(row_id: action.row_id, action_tstamp_tx: action.action_tstamp_tx).max
      end

      interest_id =
        (
          action.changed_fields&.[]("interest_id") ||
          action.row_data["interest_id"]
        ).to_i

      if action.action_tstamp_tx < removed_restricted
        interest_id -= 1 if interest_id > 8
        interest_id -= 1 if interest_id > 10
      end

      if action.action_tstamp_tx < open_tryout_added
        interest_id += 1 if interest_id > 6
      end

      raise "Interest Not Found" unless Interest.level(interest_id).present?


      action.
        record.
        interest_histories.create!  \
          interest_id:    interest_id,
          changed_by_id:  action.app_user_id ||
                          auto_worker&.id,
          created_at:     action.action_tstamp_tx \
        unless action.
                record.
                interest_histories.order(:created_at).
                where(User::InterestHistory.arel_table[:created_at].lteq(action.action_tstamp_tx)).
                select(:interest_id).
                last&.interest_id == interest_id
    rescue
      pp action
      raise
    end
  ensure
    ActiveRecord::Base.logger = logger
  end
end
