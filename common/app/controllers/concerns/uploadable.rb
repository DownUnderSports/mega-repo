module Uploadable
  extend ActiveSupport::Concern

  def whitelisted_upload_params
    params.require(:upload).permit(:file)
  end

  def csv_upload(uploaded)
    verify_file(uploaded)

    {
      name: uploaded.original_filename,
      "mime-type" => uploaded.content_type,
      size: view_context.number_to_human_size(uploaded.size),
      body: Encoder.new(uploaded.read).to_utf8
    }
  end

  private
    def verify_file(file)
      unless correct_mime_type(file) && /\.csv/ =~ file.original_filename
        raise "Only csv files with the correct headers are allowed"
      end
    end

    def correct_mime_type(file)
      [
        "text/csv",
        "text/plain",
        "application/vnd.ms-excel",
        "text/x-csv",
        "application/csv",
        "application/x-csv",
        "text/csv",
        "text/comma-separated-values",
        "text/x-comma-separated-values"
      ].any? {|mime| mime == file.content_type}
    end

    def open_tempfile(ext: '.csv', tempdir: nil)
      require 'tempfile'

      file = Tempfile.open([ rand.to_s.sub(/^0\./, ''), ext ], tempdir)

      begin
        yield file
      ensure
        file.close!
      end
    end
end
