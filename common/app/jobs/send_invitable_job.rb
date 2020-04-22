class SendInvitableJob < ApplicationJob
  queue_as :important

  def perform(user_id, params = {})
    start_time = Time.zone.now
    object_path = "tmp/imports/invitable/#{rand}-#{start_time.to_i}.csv"

    object = s3_bucket.object(object_path)
    start = params[:start]&.to_i || 0
    objects_to_combine = params[:files].presence || []
    objects_to_combine = [ combine_files(objects_to_combine) ] if objects_to_combine.size >= 10

    i = 0
    incomplete = false

    begin
      object.
        upload_stream(tempfile: true) do |write_stream|
          write_stream << to_csv(Invite.invitable_headers)
          Invite.invitable_rows(params) do |row, id|
            write_stream << to_csv(row) unless id.present?
            if (((i += 1) > 1) && (i % 5_000 == 0)) || ((Time.zone.now - start_time) > 15.minutes) || work_is_stopping?
              start = (id || row[0]).to_i + 1
              incomplete = true
              break
            end
          end
        end
    rescue Exception
      object.delete
      ErrorMailer.with(
        message: $!.message,
        stack: $!.backtrace,
        additional: {
          job: 'SendInvitableJob',
          file_path: object_path,
        }
      ).ruby_error.deliver_later
      raise
    end

    if incomplete
      return SendInvitableJob.perform_later(user_id, params.merge({ start: start, files: [ *objects_to_combine, object_path ] }))
    elsif objects_to_combine.present?
      object_path = combine_files(objects_to_combine | [ object_path ])
    end

    user = (user = User.get(user_id))&.is_dus_staff? ? user : nil

    FileMailer.
      with(
        object_path: object_path,
        compress: true,
        file_name: "invitable-users_#{Date.today.to_s}.csv",
        email: user&.email&.presence || 'it@downundersports.com',
        subject: 'Invitable Users',
        message: 'All athletes in the system with a valid grad year',
        delete_file: "keep_download",
      ).
      send_s3_file.
      deliver_later(queue: :staff_mailer)
  end

  def to_csv(row)
    CSV.generate_line(row, force_quotes: true, encoding: 'utf-8')
  end

  def combine_files(file_list)
    object_path = "tmp/imports/invitable/#{rand}-#{Time.zone.now.to_i}.csv"
    combo_object = s3_bucket.object(object_path)
    begin
      combo_object.
        upload_stream(tempfile: true) do |write_stream|
          write_stream << to_csv(Invite.invitable_headers)

          file_list.each do |o_path|
            begin
              object = s3_bucket.object(o_path)
              path = Rails.root.join('public', File.basename(o_path)).to_s
              object.download_file path
              object.delete
              i = 0

              CSV.open(path) do |parsed|
                parsed.each do |row|
                  if i == 0
                    i += 1
                  elsif row.to_a.present?
                    write_stream << to_csv(row.to_a)
                  end
                end
              end
            rescue
              ErrorMailer.with(
                message: $!.message,
                stack: $!.backtrace,
                additional: {
                  job: 'SendInvitableJob',
                  file_path: o_path,
                  file_list: file_list.join("; ")
                }
              ).ruby_error.deliver_later
            end
          end
        end
    rescue Exception
      ErrorMailer.with(
        message: $!.message,
        stack: $!.backtrace,
        additional: {
          job: 'SendInvitableJob',
          file_list: file_list.join("; ")
        }
      ).ruby_error.deliver_later

      combo_object.delete
      raise
    end
    object_path
  end
end
