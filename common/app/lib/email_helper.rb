module EmailHelper
  def get_full_path_to_asset(filename)
    manifest_file = Rails.application.assets_manifest.assets[filename]
    if manifest_file
      File.join(Rails.application.assets_manifest.directory, manifest_file)
    else
      Rails.application.assets&.[](filename)&.filename
    end
  end
  
  def email_image_tag(image, **options)
    if Rails.env.development?
      attachments[image] = {
        mime_type: "image/#{image.split(".")[-1]}",
        content: File.read(get_full_path_to_asset(image))
      }
      image = attachments[image].url
    end
    image_tag image, **options
  end
end
