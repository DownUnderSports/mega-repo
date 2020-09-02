# encoding: utf-8
# frozen_string_literal: true

### IMPORTANT: SPLIT FILES INTO 15k ROWS BEFORE UPLOADING   ###
### RUN FILE COUNT WITH heroku_db_seed FILE_NUMBER_HERE     ###
###############################################################

require_dependency 'import'

module Import
  class Processor
    # == Constants ============================================================

    # == Attributes ===========================================================
    attr_accessor :bad_rows, :bad_headers, :count, :csv_file_name,
                  :csv_file_path, :dry_run, :dups, :idx, :object_path,
                  :quiet_import, :skip_invalid, :start_time, :row_identifier,
                  :row_identifier_column, :work_is_stopping
                  # :quiet_import, :schools, :skip_invalid, :sports,

    # == Extensions ===========================================================
    class PurposefulError < StandardError
    end

    class RowInvalidError < StandardError
    end

    # == Relationships ========================================================

    # == Validations ==========================================================

    # == Scopes ===============================================================

    # == Callbacks ============================================================

    # == Boolean Class Methods ================================================

    # == Class Methods ========================================================
    def self.headers
      %w[
        allow_no_grad
        source
        first
        last
        gender
        grad
        stats
        state_abbr
        school_name
        school_street
        school_street_2
        school_city
        school_state_abbr
        school_zip
        school_pid
        sport_abbr
        main_event_best
        main_event
        rank
        invited_date
        student_list_sent
        student_list_rec
        txfr_school_id
        street
        city
        home_state_abbr
        zip
      ]
    end

    def self.file_name
      "import-#{Time.zone.now.strftime("%Y-%m-%m_%H-%M-%S")}-#{rand}.csv"
    end

    def self.base_folder
      "tmp/imports"
    end

    def self.requeue_job_name
      Import::ProcessFileJob
    end

    def self.run(**opts)
      job = new(**opts)
      result = job.run
      if result == :job_stopped
        requeue_job_name.perform_later opts.except(:work_is_stopping).merge(
          row_identifier: job.row_identifier,
          row_identifier_column: job.row_identifier_column,
          idx: job.idx,
          dups: job.dups
        )
      end
    end

    def self.parse_file(csv_file, current_user_id: nil, **opts)
      upload_file_name = File.basename(opts[:path].presence || file_name, '.csv')

      i = f = 0
      csv = +""
      row_headers = []
      files = []
      row_id_key = "ROW_ID_#{rand.to_s.split(".").last}"

      save_file = -> do
        files << (path = "#{upload_file_name}-#{f}.csv")
        save_to_s3 "#{self.base_folder}/#{path}", csv
        csv = +""
        puts "\n#{path}\n"
      end

      CSV.open(csv_file) do |parsed|
        parsed.each do |row|
          if (i % 10_000) == 0
            if i > 0
              save_file.call
            else
              row_headers = row.to_a.map(&:to_s)
              row_headers.map!(&:downcase) unless row_headers.size == 2
              row_headers.unshift row_id_key
            end

            f += 1
            csv << CSV.generate_line(row_headers, encoding: 'UTF-8')
            if i == 0
              i += 1
              next
            end
          end

          if row.to_a.present?
            csv << CSV.generate_line([ "#{i}.#{rand}" ] + row.to_a, encoding: 'UTF-8')
            print "\r#{i += 1} Records"
          end
        end
      end
      puts ''

      save_file.call

      if (row_headers.size == 3) && row_headers.any?('DUS_ID') && row_headers.any?('SEND_DATE')
        return files.each do |path|
          Invite::MarkDatesJob.perform_later opts.merge(path: path, object_base: self.base_folder, count: [i, 10_000].min, row_identifier_column: row_id_key)
        end
      elsif (row_headers.size.in? 3..4) && row_headers.any?('DUS_ID') && row_headers.any?('AMOUNT')
        return files.each do |path|
          GenerateQrCodesJob.perform_later opts.merge(path: path, current_user_id: current_user_id || auto_worker.id, object_base: self.base_folder, count: [i, 10_000].min, row_identifier_column: row_id_key)
        end
      end

      files.each do |path|
        Import::ProcessFileJob.perform_later opts.merge(path: path, count: [i, 10_000].min, row_identifier_column: row_id_key)
      end
    end

    def self.bad_imports
      files = s3_bucket.objects(prefix: "#{self.base_folder}/bad_rows").collect(&:key)
      object_path = csv_file_path = nil
      row_headers = []
      rows = []

      loop do
        object_path = "errors-" + file_name
        csv_file_path = Rails.root.join("tmp", "bad_imports", object_path)
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
            row_headers |= r.keys.map(&:to_s)
            rows << r.with_indifferent_access
          end
        end
        object.delete
      end

      if rows.present?
        csv = +"" + CSV.generate_line(row_headers, encoding: 'UTF-8')

        rows.each do |row|
          csv << CSV.generate_line(row_headers.map{|k| row[k]}, encoding: 'UTF-8') if row.present?
        end

        object_path = "#{self.base_folder}/return_file/#{object_path}"

        s3_bucket.object(object_path).put(body: csv)

        FileMailer.
          with(
            object_path: object_path,
            email: 'it@downundersports.com',
            subject: 'Import Errors',
            message: 'Attached are rows that caused errors when importing',
            delete_file: true
          ).
          send_s3_file.
          deliver_later(queue: :staff_mailer)
      end
    end

    # == Boolean Methods ======================================================

    # == Instance Methods =====================================================
    def initialize(path:, object_base: nil, count: nil, dry_run: false, quiet_import: false, skip_invalid: false, work_is_stopping: nil, row_identifier: nil, row_identifier_column: nil, idx: 0, dups: 0)
      require 'csv'
      require 'fileutils'

      self.row_identifier = row_identifier
      self.row_identifier_column = row_identifier_column.presence || 'ROW_ID'
      self.work_is_stopping = work_is_stopping

      self.csv_file_path = Rails.root.join(self.class.base_folder, self.class.file_name)

      dirname = File.dirname(csv_file_path)
      unless File.directory?(dirname)
        FileUtils.mkdir_p(dirname)
      end

      self.object_path = "#{object_base || self.class.base_folder}/#{path}"

      s3_bucket.object(object_path).download_file csv_file_path

      self.csv_file_name = File.basename(path)
      self.count = count.presence&.to_i || `wc -l #{path}`.to_i - 1

      self.dry_run = dry_run
      self.quiet_import = quiet_import
      self.skip_invalid = skip_invalid

      self.idx = idx.to_i
      self.dups = dups.to_i

      # self.schools = {}
      # self.sports = {}
      # self.states = {}
      # self.lists = {}
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
      puts "Seeding invited athletes from #{csv_file_path}"

      @found_start = self.row_identifier.blank?
      @job_stopped = false
      CSV.foreach(csv_file_path, headers: true, encoding: 'bom|utf-8') do |row|
        if self.work_is_stopping&.call
          self.row_identifier = row[self.row_identifier_column] unless !@found_start
          @job_stopped = true
          break
        elsif !@found_start
          @found_start = row[self.row_identifier_column] == self.row_identifier
          next unless @found_start
        end

        self.idx += 1
        # if (idx % 7500 == 0)
          # self.schools = {}
          # self.sports = {}
          # self.states = {}
          # self.lists = {}
        # end

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
          rescue ActiveRecord::ActiveRecordError, RowInvalidError
            self.bad_headers |= row.to_h.keys.map(&:to_s)
            self.bad_rows << row.to_h.stringify_keys.merge("error" => $!.message)
          end
        else
          parse_row row
        end

        print "#{idx} of #{count} athletes (#{dups} dups)      \r" unless quiet_import
        puts "#{idx} of #{count} athletes (#{dups} dups) in #{time_format}                              " if (idx % 1000 == 0) && !quiet_import
      end

      if @job_stopped
        queue_bad_rows if bad_rows.present?
        return :job_stopped
      end

      puts "#{count} of #{count} athletes (#{dups} dups) in #{time_format}                            "
      s3_bucket.object(object_path).delete

      queue_bad_rows if bad_rows.present?
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
        row = row.to_h.with_indifferent_access
        source = sport = school = state = nil

        unless row[:dus_id].present? && User.get(row[:dus_id])
          row[:verified] = true
          student_list = nil

          row.each do |k, v|
            row[k].gsub!(/['’`]/, "'") if v.is_a?(String)
          end

          %i[
            email
            phone
            parent_phone
            parent_email
            second_parent_phone
            second_parent_email
          ].each do |k|
            row[k] = row[k].to_s.strip.presence&.downcase
          end

          %w[
            first
            parent_first
            second_parent_first
            last
            parent_last
            second_parent_last
            suffix
            parent_suffix
            second_parent_suffix
          ].each do |k|
            row[k] = row[k].to_s.strip.presence&.titleize
            if row[k] && (k =~ /last$/) && (row[k] =~ /.*\s+([js]r|[iv]+)\.?$/i)
              v = row[k].split(/\s+/)
              row[k] = v[0...-1].join(' ').titleize
              row[k.sub('last', 'suffix')] = v[-1].titleize
            end
          end

          row[:email] = nil if row[:email] && ((row[:email] == row[:parent_email]) || (row[:email] == row[:second_parent_email]) || User.find_by(email: row[:email]))
          row[:second_parent_email] = nil if row[:parent_email] == row[:second_parent_email]

          row[:grad] = "20#{row[:grad].rjust(4, '0')[-2..-1]}".to_i if row[:grad].present?

          %i[
            student_list_rec
            student_list_sent
            invited_date
          ].each {|k| row[k].us_date_to_iso! if row[k].to_s =~ /\d+\/\d+\/\d+/ }

          if row[:student_list_sent].to_s == '25-Dec-10'
            row[:student_list_rec] = nil
            source = Source.get_or_create!("18-co-#{row[:source]}")
            student_list = nil
          else
            source = Source.get_or_create!(row[:source])
            student_list =
              row[:student_list_sent].presence &&
              StudentList.find_by(sent: Date.parse(row[:student_list_sent]))
          end
          # row[:school_pid] = "#{row[:school_pid]}".pid_format
          row[:school_pid] = nil if row[:school_pid].to_s =~ /^(PID\|?)*\d\.?\d+[Ee]\+?\d{1,3}$/
          row[:school_pid] = row[:school_pid].presence&.sub(/^(PID\|?)*0*/, '')&.pid_format
          # school = row[:school_pid].presence && (schools[row[:school_pid]] ||= School.find_by(pid: row[:school_pid].to_s))
          school = row[:school_pid].presence && School.find_by(pid: row[:school_pid].to_s)
          sport = Sport.find_by(abbr_gender: row[:sport_abbr])
          state = State.find_by(abbr: row[:state_abbr] || row[:state] || row[:school_state_abbr])

          begin
            raise RowInvalidError.new("First Name required for importing") unless row[:first].present?
            raise RowInvalidError.new("Last Name required for importing") unless row[:last].present?

            if !student_list && row[:student_list_rec].present?
              p "STUDENT LIST: ", Date.parse(row[:student_list_sent]), Date.parse(row[:student_list_rec]) unless quiet_import
              student_list =
                StudentList.create!(
                  sent: Date.parse(row[:student_list_sent]),
                  received: Date.parse(row[:student_list_rec]),
                )
            end

            if row[:txfr_school_id].present?
              og_school = school

              school = School.import_from_transfer_id(row[:txfr_school_id]) || og_school

              row[:school_pid] = school.pid unless !school || row[:school_pid].present?
            end

            if !school && row[:school_street].present?
              sch_addr = nil
              set_sch_address = ->() {
                unless sch_addr&.id
                  sch_addr = sch_addr&.find_variant_by_value&.address || Address.find_or_initialize_by(
                    street: row[:school_street],
                    street_2: row[:school_street_2],
                    city: row[:school_city],
                    state: State.find_by_value(row[:school_state_abbr]),
                    zip: row[:school_zip]
                  )
                end
              }

              2.times { sleep(rand * 5); set_sch_address.call }
              retries = 0
              begin
                unless sch_addr.id
                  if Address.no_processing
                    sch_addr.save!
                  else
                    Address.process_batches
                    sch_addr.batch_processing = true
                    sch_addr.save!
                    Address.process_batches
                    sch_addr = sch_addr.find_variant_by_value&.reload&.address
                  end
                end
              rescue
                raise if (retries += 1) > 3
                sleep(rand * 5);
                set_sch_address.call
                retry
              end

              og_pid = pid = row[:school_pid].to_s.sub(/^0+/, '').presence&.pid_format

              if !pid || School.is_custom?(row[:school_pid].to_s)
                pid = School.custom_pid(sch_addr, row[:school_name])
                school = School.find_by(pid: pid)
              end

              school ||= (sch_addr && School.find_by(address: sch_addr, name: row[:school_name].titleize)) || School.create!(
                pid: pid,
                name: row[:school_name],
                address: sch_addr,
                allowed: true,
                allowed_home: true,
                closed: false,
              )

              # schools[pid] = school
              # schools[row[:school_pid]] = og_pid.blank? ? nil : school
            end

            gender = row[:gender].to_s[0]&.upcase || 'U'
            gender = 'U' unless gender.to_s =~ /M|F|U/

            address = row[:street].present? ?
              Address.new(
                **row.slice(
                  :is_foreign,
                  :street,
                  :street_2,
                  :street_3,
                  :city,
                  :province,
                  :zip,
                  :country,
                  :rejected,
                  :verified
                ).deep_symbolize_keys,
                student_list: student_list,
                state: (row[:home_state_abbr].presence && State.find_by(abbr: row[:home_state_abbr])) || state
              ) :
              school.address

            row[:stats] = row[:stats].presence && row[:stats].split("\n\n").map(&:strip).uniq.join("\n\n")

            sch_users =
              school.users.
                joins(:athlete).
                where((gender == 'U') ? '1=1' : { gender: [gender, 'U'] }).
                where(
                  "(lower(users.first) || ' ' || lower(users.last)) % (:first || ' ' || :last)",
                  first: row[:first].downcase,
                  last: row[:last].downcase
                )

            u =
              sch_users.
                where(
                  *(
                    row[:grad].present? ?
                    ["athletes.grad = ?", row[:grad].to_i] :
                    ["athletes.grad >= ?", current_year.to_i]
                  )
                ).limit(1).take ||
              sch_users.
                where('athletes.grad IS NULL').limit(1).take

            if u
              self.dups += 1
              puts "Found User #{u.print_names}, dup #: #{dups}, row: #{idx}" unless quiet_import
              athlete = u.athlete

              u.update!(gender: gender) if (u.gender == 'U') && (gender != 'U')

              if as = athlete.athletes_sports.find_by(sport: sport)
                if row[:stats].present?
                  if as.stats.present?
                    row[:stats].split("\n\n").each do |stat|
                      as.stats += "\n\n" + stat unless as.stats.include? stat
                    end
                  else
                    as.stats = row[:stats]
                  end
                  as.save!
                end
              else
                athlete.athletes_sports.create!(
                  sport: sport,
                  rank: row[:rank].presence.to_i,
                  main_event: row[:main_event],
                  main_event_best: row[:main_event_best],
                  stats: row[:stats],
                  invited: row[:invited_date].present?,
                  invited_date: row[:invited_date].presence && Date.parse(row[:invited_date])
                )
              end

              return false if u.respond_date

              u.update!(address: address) if row[:street].present? && u.address_id.blank?
              u.update!(phone: row[:phone]) if row[:phone].to_s.strip.present? && u.phone.blank?
              u.update!(email: row[:email]) if row[:email].to_s.strip.present? && u.email.blank?

              athlete.update!(sport: sport, grad: athlete.grad.presence || row[:grad].presence)

              if current_year
                raise RowInvalidError.new("Year Grad required for importing") unless athlete.grad.present? || Boolean.parse(row[:allow_no_grad])
                raise RowInvalidError.new("Graduated before this year") if athlete.grad.presence&.to_i&.<(current_year.to_i)
              end
            else
              if current_year
                raise RowInvalidError.new("Year Grad required for importing") unless row[:grad].present? || Boolean.parse(row[:allow_no_grad])
                raise RowInvalidError.new("Graduated before this year") if row[:grad].presence&.to_i&.<(current_year.to_i)
              end
              athlete = nil
              begin
                athlete = ::Athlete.create!(
                  grad: row[:grad].presence,
                  school: school,
                  source: source,
                  sport: sport,
                  original_school_name: row[:school_name],
                  txfr_school_id: row[:txfr_school_id],
                  athletes_sports_attributes: [
                    {
                      sport: sport,
                      rank: row[:rank].presence.to_i,
                      main_event: row[:main_event],
                      main_event_best: row[:main_event_best],
                      stats: row[:stats],
                      invited: row[:invited_date].present?,
                      invited_date: row[:invited_date].presence && Date.parse(row[:invited_date])
                    }
                  ]
                )
              rescue
                p "SCHOOL:", school
                puts "ROW: ", row, "SCHOOL ATTRS: ", school&.attributes, "ATHLETE_ATTRS: ", athlete&.attributes
                raise
              end

              u = User.create!(
                gender: gender,
                category: athlete,
                address: (row[:street].present? ? address : nil),
                **row.slice(*User.attribute_names).deep_symbolize_keys
              )
            end

            if row[:parent_first].present? && !u.related_users.find_by(first: row[:parent_first], last: row[:parent_last])
              g = User.create!(
                first: row[:parent_first],
                last: row[:parent_last],
                email: row[:parent_email],
                phone: row[:parent_phone],
              )
              rel = u.relations.create!(
                relationship: :parent,
                related_user: g
              )
            end

            if row[:second_parent_first].to_s.strip.present? && !u.related_users.find_by(first: row[:second_parent_first], last: row[:second_parent_last])
              g_s = User.create!(
                first: row[:second_parent_first],
                last: row[:second_parent_last],
                email: row[:second_parent_email],
                phone: row[:second_parent_phone],
              )
              rel_s = u.relations.create!(
                relationship: :parent,
                related_user: g_s
              )
            end

            row[:dus_id] = u.reload.dus_id

            if row[:invited_date].present? || Boolean.parse(row[:infokit])
              m = u.mailings.build
              m.address = u.address || address
              m.is_home = (u.address || row[:street]).present?
              if Boolean.parse(row[:infokit])
                m.category = :infokit
              else
                m.sent = Date.parse(row[:invited_date])
                m.category = m.is_home ? 'invite_home' : 'invite_school'
              end
              m.save!
            end
          rescue
            unless quiet_import
              p "___ROW_ERROR___ #{$!.message}", "IDX: #{idx.inspect}", "ROW: #{row.inspect}", "SCHOOL: #{school.inspect}, SOURCE: #{source.inspect}"
              p Source.get_or_create(row[:source])
              puts $!.backtrace
            end
            raise
          end
        end
      end
  end
end
