class QrCodesMailer < FileMailer
  def send_folder
    return false unless (folder_path = params[:folder_path]).present?
    current_user = User[params[:user_id]] || auto_worker

    rand_file_name = "qr-codes_#{Time.zone.now.strftime("%Y-%m-%m_%H-%M-%S")}"
    files = s3_bucket.objects(prefix: folder_path).collect(&:key)
    tmp_folder = Rails.root.join("tmp", "qr_codes", "#{rand_file_name}_#{rand}".gsub(/\./, ''))

    FileUtils.mkdir_p(tmp_folder)

    @message = "Your QR Codes are Ready"
    @file_name = "#{rand_file_name}.tar.gz"
    @object_path = QrCodeProcessor.base_folder + "/compressed/#{@file_name}"

    files.each do |file|
      object = s3_bucket.object(file)
      object.download_file "#{tmp_folder}/#{File.basename(file)}"
    end

    open_tempfile(ext: "tar.gz") do |file|
      %x{ bash -c "tar -czf \\"#{file.path}\\" -C \\"#{File.dirname(tmp_folder)}\\" \\"#{File.basename(tmp_folder)}/\\"" }

      file.flush
      file.rewind

      save_to_s3 @object_path, file
    end


    mail to: current_user.email || 'it@downundersports.com', subject: @message
  end
end
