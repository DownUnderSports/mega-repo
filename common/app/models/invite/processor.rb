# encoding: utf-8
# frozen_string_literal: true

### IMPORTANT: SPLIT FILES INTO 15k ROWS BEFORE UPLOADING   ###
### RUN FILE COUNT WITH heroku_db_seed FILE_NUMBER_HERE     ###
###############################################################

require_dependency 'invite'
require_dependency 'import/processor'

module Invite
  class Processor < Import::Processor
    # == Constants ============================================================

    # == Attributes ===========================================================

    # == Extensions ===========================================================

    # == Relationships ========================================================

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.headers
      %w[
        DUS_ID
        SEND_DATE
      ]
    end

    def self.display_headers
      [
        'DUS_ID',
        'SEND_DATE (YYYY-MM-DD)'
      ]
    end

    def self.file_name
      "invite-#{Time.zone.now.strftime("%Y-%m-%m_%H-%M-%S")}-#{rand}.csv"
    end

    def self.base_folder
      "tmp/invites"
    end

    def self.requeue_job_name
      Invite::MarkDatesJob
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================


    private
      def time_format
        s = Time.now - start_time
        m = (s - (s % 60)) / 60
        h = ((m - (m % 60)) / 60).to_i.to_s.rjust(2, '0')
        m = (m % 60).to_i.to_s.rjust(2, '0')
        s = s % 60
        "#{h}:#{m}:#{s} (h:m:s.ss)"
      end

      def export_bad_rows
        bad_csv = +""
        bad_csv << CSV.generate_line(bad_headers, encoding: 'UTF-8')
        bad_rows.each do |r|
          bad_csv << CSV.generate_line(bad_headers.map{|k| r[k]}, encoding: 'UTF-8')
        end
        s3_bucket.object("#{self.class.base_folder}/bad_rows/#{csv_file_name}").put(body: bad_csv)
      end

      def queue_bad_rows
        Sidekiq::ScheduledSet.new.select do |job|
          args = job.args[0] || {}
          args['job_class'] == 'Import::SendBadRecordsJob'
        end.each(&:delete)

        export_bad_rows

        Import::SendBadRecordsJob.set(wait_until: 1.hour.from_now).perform_later
      end

      def parse_row(row)
        row = row.to_h

        raise RowInvalidError.new("User Not Found") unless row['DUS_ID'].present? && (user = User.get(row['DUS_ID']))
        raise RowInvalidError.new("Invalid Date") unless row['SEND_DATE'].present? && (row['SEND_DATE'] = Date.parse(row['SEND_DATE'].us_date_to_iso_if_needed) rescue nil)
        return user.mailings.invites.find_by(sent: row['SEND_DATE']) if user.mailings.invites.where(sent: row['SEND_DATE']).exists?

        address = user.main_address&.unrejected
        mailing =
          user.mailings.invites.where(sent: nil).take ||
          (
            address ? user.mailings.home_invites : user.mailings.school_invites
          ).build(address: address || user.athlete&.school&.address, is_home: !!address)

        mailing.sent = row['SEND_DATE']
        mailing.save!
        mailing
      end
  end
end
