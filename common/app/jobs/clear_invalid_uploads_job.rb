class ClearInvalidUploadsJob < ApplicationJob
  queue_as :default

  def perform(*args)
    ActiveStorage::Attachment.where("name ILIKE '%user_signed_terms'").each do |a|
      if a.content_type !~ /^application\/pdf$/i
        a.record.touch
        a.purge
      end
    end

    ActiveStorage::Blob.where("created_at < ?", 1.hour.ago).where_not_exists(:attachments).each(&:purge)
  end
end
