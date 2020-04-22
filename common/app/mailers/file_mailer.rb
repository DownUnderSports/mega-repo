class FileMailer < ImportantMailer
  def send_file
    return false unless params[:template].present? && params[:extension].present?

    @message = params[:message].presence || "Here is your file"

    attachments["#{params[:name] || 'requested_file'}_#{Time.now.strftime('%Y-%b-%d_%H-%M-%S').upcase}.#{params[:extension]}"] = {
      mime_type: Mime[(params[:mime_type] || params[:extension]).to_sym],
      content: render(
        layout: false,
        handlers: [(params[:handler] || params[:extension]).to_sym],
        formats: [(params[:format] || params[:extension]).to_sym],
        template: params[:template]
      )
    }

    mail to: params[:email] || 'it@downundersports.com', subject: params[:subject].presence || @message
  end

  def send_s3_file
    return false unless (object_path = params[:object_path]).present?

    @message = params[:message].presence || "A file has been sent to you"
    @on_download = (params[:delete_file] == "on_download") && 1
    @on_download ||= (params[:delete_file] == "keep_download") && 0
    file_name = File.basename(params[:file_name].presence || object_path)

    if @on_download
      @file_name = file_name
      @object_path = object_path
    else
      open_tempfile(ext: File.extname(file_name)) do |file|
        file.binmode
        stream(object_path, params[:delete_file].presence) { |chunk| file.write(chunk) }
        file.flush
        file.rewind
        if Boolean.parse(params[:compress].presence)
          open_tempfile(ext: '.gz') do |gzfile|
            gzfile.binmode

            Zlib::GzipWriter.open(gzfile, Zlib::BEST_COMPRESSION) do |gz|
              gz.mtime = Time.zone.now
              gz.orig_name = file_name
              while chunk = file.read(16*1024) do
                gz.write(chunk)
              end
            end

            gzfile.flush
            gzfile.rewind

            attachments["#{file_name}.gz"] = gzfile.read
          end
        else
          attachments[file_name] = file.read
        end
      end
    end


    mail to: params[:email] || 'it@downundersports.com', subject: params[:subject].presence || @message
  end

  private
    def open_tempfile(ext: '.csv', tempdir: nil)
      require 'tempfile'

      file = Tempfile.open([ rand.to_s.sub(/^0\./, ''), ext ], tempdir)

      begin
        yield file
      ensure
        file.close!
      end
    end

    # Reads the object for the given key in chunks, yielding each to the block.
    def stream(key, should_delete = false)
      object = s3_bucket.object(key)

      chunk_size = 5.megabytes
      offset = 0

      while offset < object.content_length
        yield object.get(range: "bytes=#{offset}-#{offset + chunk_size - 1}").body.read.force_encoding(Encoding::BINARY)
        offset += chunk_size
      end
      object.delete if Boolean.parse(should_delete)
    end
end
