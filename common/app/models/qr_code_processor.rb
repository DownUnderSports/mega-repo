# encoding: utf-8
# frozen_string_literal: true

### IMPORTANT: SPLIT FILES INTO 15k ROWS BEFORE UPLOADING   ###
### RUN FILE COUNT WITH heroku_db_seed FILE_NUMBER_HERE     ###
###############################################################

require_dependency 'invite/processor'

class QrCodeProcessor < Invite::Processor
  # == Constants ============================================================

  # == Attributes ===========================================================
  attr_accessor :img_assets_path, :current_user_id

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
      AMOUNT
    ]
  end

  def self.display_headers
    [
      'DUS_ID',
      'AMOUNT ([0-9]+.[0-9]{2})'
    ]
  end

  def self.file_name
    "qr-code-#{Time.zone.now.strftime("%Y-%m-%m_%H-%M-%S")}-#{rand}.csv"
  end

  def self.base_folder
    "tmp/qr_codes"
  end

  def self.requeue_job_name
    GenerateQrCodesJob
  end

  def self.tmp_asset_path
    "#{base_folder}/images/job-#{Time.zone.now.strftime("%Y-%m-%m_%H-%M-%S")}-#{rand}"
  end

  class << self
    def generate(url)
      generate_qr_code(url).as_png(size: 500).replace!(qr_logo, 200, 200)
    end

    def qr_logo
      @qr_logo ||= ChunkyPNG::Image.from_file(Rails.root.join('vendor', 'common', 'permanent', 'qr-logo-100.png'))
    end

    def free_space
      @qr_logo = nil
    end
  end

  # == Boolean Methods ======================================================

  # == Instance Methods =====================================================
  def initialize(img_assets_path:, current_user_id: auto_worker.id, **opts)
    self.img_assets_path = img_assets_path
    self.current_user_id = current_user_id
    super(**opts)
  end

  def run
    result = super
    unless result == :job_stopped
      QrCodesMailer.
        with(user_id: self.current_user_id, folder_path: self.img_assets_path).
        send_folder.
        deliver_later
    end
    result
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
      s3_bucket.object("#{self.class.base_folder}/bad_rows/#{csv_file_name}").put(body: bad_csv)
    end

    def queue_bad_rows
      Sidekiq::ScheduledSet.new.select do |job|
        args = job.args[0] || {}
        args['job_class'] == 'SendBadQrCodesJob'
      end.each(&:delete)

      export_bad_rows

      SendBadQrCodesJob.set(wait_until: 1.hour.from_now).perform_later
    end

    def parse_row(row)
      row = row.to_h

      raise RowInvalidError.new("User Not Found") unless row['DUS_ID'].present? && (user = User.get(row['DUS_ID']))
      raise RowInvalidError.new("Invalid Amount") unless row['AMOUNT'].blank? || ((row['AMOUNT'] = StoreAsInt.money(row['AMOUNT']) rescue nil).to_i > 0)

      url = "https://www.downundersports.com/"
      url += user.traveler ? 'payment/' : 'deposit/' unless Boolean.parse(row['ALLOW_INFOKIT'])
      url += user.dus_id
      url += "?amount=#{row['AMOUNT'].to_s}" if row['AMOUNT'].present?

      open_tempfile do |file|
        file.binmode
        QrCodeProcessor.generate(url).write(file)

        file.flush
        file.rewind
        save_to_s3 "#{self.img_assets_path}/#{user.dus_id}.png", file
      end

      true
    end

    def open_tempfile(ext: '.png', tempdir: nil)
      require 'tempfile'

      file = Tempfile.open([ rand.to_s.sub(/^0\./, ''), ext ], tempdir)

      begin
        yield file
      ensure
        file.close!
      end
    end
end
