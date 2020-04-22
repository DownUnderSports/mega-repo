### IMPORTANT: SPLIT FILES INTO 15k ROWS BEFORE UPLOADING   ###
### RUN FILE COUNT WITH heroku_db_seed FILE_NUMBER_HERE     ###
###############################################################

require 'csv'

class PurposefulError < StandardError
end

# heroku run --size=standard-2x rails db:seed INV_COUNT=4
csv_file_name = "invited#{ENV["INV_COUNT"].present? ? "-#{ENV["INV_COUNT"]}" : ''}.csv"
path = File.join(__dir__, csv_file_name)
count = ENV["RECORDS_PER_SHEET"].presence&.to_i || `wc -l #{path}`.to_i - 1
dry_run = Boolean.parse(ENV['DRY_RUN'])
quiet_import = ENV['QUIET_IMPORT'].present?
skip_invalid = Boolean.parse(ENV['SKIP_INVALID'])

i = 0
f = 0

sources = {}
schools = {}
sports = {}
states = {}
lists = {}
# StudentList.create!(
#   sent: '2018-09-27',
#   received: '2018-09-27',
# ) unless StudentList.find_by(sent: '2018-09-27')
#
# student_list = StudentList.find_by(sent: '2018-09-12')
start_time = Time.now

time_format = ->() do
  s = Time.now - start_time
  m = (s - (s % 60)) / 60
  h = ((m - (m % 60)) / 60).to_i.to_s.rjust(2, '0')
  m = (m % 60).to_i.to_s.rjust(2, '0')
  s = s % 60
  "#{h}:#{m}:#{s} (h:m:s.ss)"
end

puts "Seeding invited athletes from #{path}"

parse_row = ->(row) do
  row = row.to_h.with_indifferent_access
  i += 1
  if (i % 7500 == 0)
    sources = {}
    schools = {}
    sports = {}
    states = {}
    lists = {}
  end
  unless row[:dus_id].present? && User.get(row[:dus_id])
    row[:verified] = true
    if row[:student_list_sent].to_s == '25-Dec-10'
      row[:student_list_rec] = nil
      source = (sources["18-co-#{row[:source]}"] ||= Source.get_or_create("18-co-#{row[:source]}"))
      student_list = nil
    else
      source = (sources[row[:source]] ||= Source.get_or_create(row[:source]))
      student_list = row[:student_list_sent].presence && (lists[Date.parse(row[:student_list_sent]).to_s] ||= StudentList.find_by(sent: Date.parse(row[:student_list_sent])))
    end
    # row[:school_pid] = "#{row[:school_pid]}".pid_format
    school = row[:school_pid].presence && (schools[row[:school_pid]] ||= School.find_by(pid: row[:school_pid].to_s))
    sport = (sports[row[:sport_abbr]] ||= Sport.find_by(abbr_gender: row[:sport_abbr]))
    state = (states[row[:state_abbr]] ||= State.find_by(abbr: row[:state_abbr] || row[:state]))

    begin
      if !student_list && row[:student_list_rec].present?
        p "STUDENT LIST: ", Date.parse(row[:student_list_sent]), Date.parse(row[:student_list_rec]) unless quiet_import
        student_list = (
          lists[Date.parse(row[:student_list_sent]).to_s] = StudentList.create!(
            sent: Date.parse(row[:student_list_sent]),
            received: Date.parse(row[:student_list_rec]),
          )
        )
      end

      if !school && row[:school_street].present?
        sch_addr = Address.find_or_initialize_by(
          street: row[:school_street],
          street_2: row[:school_street_2],
          city: row[:school_city],
          state: State.find_by_value(row[:school_state_abbr]),
          zip: row[:school_zip]
        )

        unless sch_addr.id
          sch_addr = sch_addr.find_variant_by_value&.address || sch_addr
          unless sch_addr.id
            sch_addr.save!
            Address::ValidateBatchJob.perform_now
            sch_addr = sch_addr.find_variant_by_value&.reload&.address
          end
        end

        og_pid = pid = row[:school_pid].to_s.sub(/0+/, '').presence&.pid_format

        if !pid || row[:school_pid].to_s =~ /^CSTM/
          pid = "#{sch_addr.state.abbr}#{sch_addr.zip}#{row[:school_name].split(' ').map(&:first).join('')}"
          school = School.find_by(pid: pid)
        end

        school ||= (sch_addr && School.find_by(address: sch_addr, name: row[:school_name].titleize)) || School.create!(
          pid: pid,
          name: row[:school_name],
          allowed: true,
          allowed_home: true,
          closed: false,
          address: sch_addr
        )

        schools[pid] = school
        schools[row[:school_pid]] = og_pid.blank? ? nil : school
      end

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

      if u = school.users.
            where(gender: row[:gender]).
            where(
              "(lower(users.first) = :first) AND (lower(users.last) = :last)",
              first: row[:first].downcase, last: row[:last].downcase
            ).limit(1).take
        f += 1
        puts "Found User #{u.print_names}, dup #: #{f}, row: #{i}" unless quiet_import
        athlete = u.athlete

        u.update!(address: address) if row[:street].present? && u.address_id.blank?

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
            invited: true,
            invited_date: row[:invited_date].presence && Date.parse(row[:invited_date])
          )
        end

        next if u.respond_date

        u.update!(address: address) if row[:street].present? && u.address_id.blank?

        athlete.update!(sport: sport)
      else
        athlete = Athlete.create!(
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
              invited: true,
              invited_date: row[:invited_date].presence && Date.parse(row[:invited_date])
            }
          ]
        )
        u = User.create!(
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

      row[:dus_id] = u.reload.dus_id

      if row[:invited_date].present?
        m = u.mailings.build
        m.address = u.address || address
        m.is_home = (u.address || row[:street]).present?
        if row[:infokit].present?
          m.category = :infokit
        else
          m.sent = Date.parse(row[:invited_date])
          m.category = m.is_home ? 'invite_home' : 'invite_school'
        end
        m.save!
      end
    rescue
      p i, row, school unless quiet_import
      raise
    end
  end
end

bad_rows = []
new_headers = []

CSV.foreach(path, headers: true, encoding: 'bom|utf-8') do |row|
  if dry_run
    begin
      ActiveRecord::Base.transaction do
        parse_row.call(row)
        raise PurposefulError.new "Clear Changes"
      end
    rescue PurposefulError
    end
  elsif skip_invalid
    begin
      ActiveRecord::Base.transaction do
        parse_row.call(row)
      end
    rescue ActiveRecord::RecordInvalid
      new_headers |= row.to_h.keys
      bad_rows << row.to_h
    end
  else
    parse_row.call(row)
  end

  print "#{i} of #{count} athletes (#{f} dups)      \r" unless quiet_import
  puts "#{i} of #{count} athletes (#{f} dups) in #{time_format.call}                              " if (i % 1000 == 0) && !quiet_import
end
puts "#{count} of #{count} athletes (#{f} dups) in #{time_format.call}                            "

bad_csv = +""
bad_csv << CSV.generate_line(new_headers, encoding: 'UTF-8')
bad_rows.each do |r|
  bad_csv << CSV.generate_line(new_headers.map{|k| r[k]}, encoding: 'UTF-8')
end
save_tmp_csv("bad_#{csv_file_name}", bad_csv)
