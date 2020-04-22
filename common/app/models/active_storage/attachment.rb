# frozen_string_literal: true
require "#{Gem::Specification.find_by_name('activestorage').gem_dir}/app/models/active_storage/attachment"

unless ActiveStorage::Attachment.private_method_defined? "attachment_created_callback"
  ActiveStorage::Attachment.include ActiveStorageAttachmentExtensions
end
