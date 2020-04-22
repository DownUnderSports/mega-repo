class ReportMailer < ImportantMailer
  def respond_totals
    mail to: 'ISSI-USA@downundersports.com', subject: "Responds/Videos Recap #{Date.yesterday.strftime("%m/%d/%Y")}" do |format|
      format.html
    end
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
