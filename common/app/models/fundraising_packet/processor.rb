# encoding: utf-8
# frozen_string_literal: true

### IMPORTANT: SPLIT FILES INTO 15k ROWS BEFORE UPLOADING   ###
### RUN FILE COUNT WITH heroku_db_seed FILE_NUMBER_HERE     ###
###############################################################

require_dependency 'fundraising_packet'

module FundraisingPacket
  class Processor
    # == Constants ============================================================

    # == Attributes ===========================================================
    attr_accessor :bad_rows, :bad_headers, :count, :csv_file_name,
                  :csv_file_path, :dry_run, :dups, :idx, :lists, :object_path,
                  :quiet_import, :schools, :skip_invalid, :sources, :sports,
                  :start_time, :states

    # == Extensions ===========================================================
    class PurposefulError < StandardError
    end

    class MissingDataError < StandardError
    end

    # == Relationships ========================================================

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.headers
      %w[
        dus_id
        email
        letter
      ]
    end

    def self.file_name
      "fundraising_packet-#{Time.zone.now.strftime("%Y-%m-%m_%H-%M-%S")}-#{rand}.csv"
    end

    def self.run(**opts)
      new(**opts).run
    end

    def self.parse_file(csv_file, **opts)
      upload_file_name = File.basename(opts[:path].presence || file_name, '.csv')

      i = f = 0
      csv = +""
      headers = []
      files = []

      save_file = -> do
        files << (path = "#{upload_file_name}-#{f}.csv")
        save_to_s3 "tmp/fundraising_packets/#{path}", csv
        csv = +""
        puts "\n#{path}\n"
      end

      CSV.open(csv_file) do |parsed|
        parsed.each do |row|
          if (i % 10_000) == 0
            if i > 0
              save_file.call
            else
              headers = row.to_a
            end

            f += 1
            csv << CSV.generate_line(headers, encoding: 'UTF-8') unless i == 0
          end

          if row.to_a.present?
            csv << CSV.generate_line(row.to_a, encoding: 'UTF-8')
            print "\r#{i += 1} Records"
          end
        end
      end
      puts ''

      save_file.call

      files.each do |f|
        FundraisingPacket::ProcessFileJob.perform_later opts.merge(path: f, count: [i, 10_000].min)
      end
    end

    def self.bad_packets
      files = s3_bucket.objects(prefix: "tmp/fundraising_packets/bad_rows").collect(&:key)
      object_path = csv_file_path = nil
      headers = []
      rows = []

      loop do
        object_path = "errors-" + file_name
        csv_file_path = Rails.root.join("tmp", "bad_packets", object_path)
        break unless File.exist?(csv_file_path)
      end

      dirname = File.dirname(csv_file_path)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end


      files.each do |file|
        object = s3_bucket.object(file)
        object.download_file csv_file_path
        CSV.foreach(csv_file_path, headers: true, encoding: 'bom|utf-8') do |row|
          r = row.to_h
          if r.present?
            headers |= r.keys.map(&:to_s)
            rows << r.with_indifferent_access
          end
        end
        object.delete
      end

      if rows.present?
        csv = +"" + CSV.generate_line(headers, encoding: 'UTF-8')

        rows.each do |row|
          csv << CSV.generate_line(headers.map{|k| row[k]}, encoding: 'UTF-8') if row.present?
        end

        object_path = "tmp/fundraising_packets/return_file/#{object_path}"

        s3_bucket.object(object_path).put(body: csv)

        FileMailer.
          with(
            object_path: object_path,
            email: 'it@downundersports.com',
            subject: 'Fundraising Packet Errors',
            message: 'Attached are rows that caused errors when setting fr packet info',
            delete_file: true
          ).
          send_s3_file.
          deliver_later(queue: :staff_mailer)
      end
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def initialize(path:, count: nil, dry_run: false, quiet_import: false, skip_invalid: false)
      require 'csv'
      require 'fileutils'

      self.csv_file_path = Rails.root.join("tmp", "fundraising_packets", self.class.file_name)

      dirname = File.dirname(csv_file_path)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end

      self.object_path = "tmp/fundraising_packets/#{path}"

      s3_bucket.object(object_path).download_file csv_file_path

      self.csv_file_name = File.basename(path)
      self.count = count.presence&.to_i || `wc -l #{path}`.to_i - 1

      self.dry_run = dry_run
      self.quiet_import = quiet_import
      self.skip_invalid = skip_invalid

      self.idx = 0

      # StudentList.create!(
      #   sent: '2018-09-27',
      #   received: '2018-09-27',
      # ) unless StudentList.find_by(sent: '2018-09-27')
      #
      # self.student_list = StudentList.find_by(sent: '2018-09-12')
      self.start_time = Time.now
      self.bad_headers = [ "error" ]
      self.bad_rows = []
      self
    end

    def run
      puts "Marking FR Packets from #{csv_file_path}"

      CSV.foreach(csv_file_path, headers: true, encoding: 'bom|utf-8') do |row|
        self.idx += 1
        if dry_run
          begin
            ActiveRecord::Base.transaction do
              parse_row row
              raise PurposefulError.new "Clear Changes"
            end
          rescue PurposefulError
          end
        elsif skip_invalid
          begin
            ActiveRecord::Base.transaction do
              parse_row row
            end
          rescue ActiveRecord::RecordInvalid, MissingDataError
            self.bad_headers |= row.to_h.keys.map(&:to_s)
            self.bad_rows << row.to_h.stringify_keys.merge("error" => $!.message)
          end
        else
          begin
            parse_row row
          rescue
            puts $!.message
            puts $!.backtrace
            raise
          end
        end

        print "#{idx} of #{count} athletes      \r" unless quiet_import
        puts "#{idx} of #{count} athletes in #{time_format}                              " if (idx % 1000 == 0) && !quiet_import
      end
      puts "#{count} of #{count} athletes in #{time_format}                            "
      s3_bucket.object(object_path).delete

      queue_bad_packets if bad_rows.present?
      puts "Complete"
    end

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
        s3_bucket.object("tmp/fundraising_packets/bad_rows/#{csv_file_name}").put(body: bad_csv)
      end

      def queue_bad_packets
        Sidekiq::ScheduledSet.new.select do |job|
          args = job.args[0] || {}
          args['job_class'] == 'FundraisingPacket::SendBadRecordsJob'
        end.each(&:delete)

        export_bad_rows

        FundraisingPacket::SendBadRecordsJob.set(wait_until: 1.hour.from_now).perform_later
      end

      def parse_row(row)
        row = row.to_h.with_indifferent_access
        u = letter_date = email_date = nil

        unless u = User.get(row[:dus_id])
          raise MissingDataError.new("User Not Found")
        end

        if row[:email].to_s =~ /\d+\/\d+\/\d+ \d+:\d+/
          dt, tm = row[:email].split(' ')
          row[:email] = "#{dt.us_date_to_iso} #{tm}"
        end

        row[:letter].us_date_to_iso! if row[:letter].to_s =~ /\d+\/\d+\/\d+/

        if row[:email].present? && (email_date = Time.zone.parse(row[:email]))
          email_date += 2000.years if email_date < '0100-01-01'.to_date
          unless u.messages.fr_packets.where(created_at: (email_date.midnight)..(email_date.end_of_day)).exists?
            u.contact_histories.fr_packets.create!(created_at: email_date, staff_id: auto_worker.category_id, category: :email)
          end
        end

        if row[:letter].present? && (letter_date = Time.zone.parse(row[:letter])&.to_date)
          letter_date += 2000.years if letter_date < '0100-01-01'.to_date
          unless u.mailings.fr_packets.where(sent: letter_date).exists?
            unless address = u.main_address || u.athlete&.school&.address
              raise MissingDataError.new("No Address for User")
            end
            u.mailings.fr_packets.create!(sent: letter_date, address: address)
          end
        end
      end
  end
end
