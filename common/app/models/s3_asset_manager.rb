# encoding: utf-8
# frozen_string_literal: true

module S3AssetManager
  def self.upload_folder(folder_path, include_folder: false, bucket: nil, prefix: '', **opts)
    self::FolderUpload.new(folder_path: folder_path, bucket: bucket || s3_bucket, include_folder: Boolean.parse(include_folder), prefix: prefix).upload! **opts
  end

  def self.object_if_exists(file_path, asset_prefix = '')
    o =
      s3_bucket.
      object("#{asset_prefix.presence && "#{asset_prefix}/"}#{file_path}")

    o.exists? && o
  end
end
