module ActiveStorageMigrator
  class Downloader #:nodoc:
    def initialize(blob, tempdir: nil)
      @blob    = blob
      @tempdir = tempdir
    end

    def download_blob_to_tempfile
      open_tempfile do |file|
        download_blob_to file
        verify_integrity_of file
        yield file
      end
    end

    private
      attr_reader :blob, :tempdir

      def open_tempfile
        file = Tempfile.open([ "ActiveStorage-#{blob.id}-", blob.filename.extension_with_delimiter ], tempdir)

        begin
          yield file
        ensure
          file.close!
        end
      end

      def download_blob_to(file)
        file.binmode
        blob.download { |chunk| file.write(chunk) }
        file.flush
        file.rewind
      end

      def verify_integrity_of(file)
        unless Digest::MD5.file(file).base64digest == blob.checksum
          raise ActiveStorage::IntegrityError
        end
      end
  end

  module AsDownloadPatch
    def open_as_tempfile(tempdir: nil, &block)
      ActiveStorageMigrator::Downloader.new(self, tempdir: tempdir).download_blob_to_tempfile(&block)
    end
  end

  def self.migrate_services(from:, to:, clear_existing: false)
    begin
      set_db_year "public"
      ActiveStorage::Blob.__send__ :include, ActiveStorageMigrator::AsDownloadPatch

      og_service = ActiveStorage::Blob.service

      begin
        configs = Rails.configuration.active_storage.service_configurations
        from_service = ActiveStorage::Service.configure from, configs
        to_service   = ActiveStorage::Service.configure to, configs

        ActiveStorage::Blob.service = from_service

        puts "#{ActiveStorage::Blob.count} Blobs to go..."
        ActiveStorage::Blob.find_each do |blob|
          print '.'
          unless to_service.exist?(blob.key) || !from_service.exist?(blob.key)
            blob.open_as_tempfile do |tf|
              checksum = blob.checksum
              to_service.upload(blob.key, tf, checksum: checksum)
            end
          end

          blob.delete if clear_existing && from_service.exist?(blob.key)
        end
      ensure
        ActiveStorage::Blob.service = og_service
      end
      puts ""
    ensure
      set_db_default_year
    end
  end
end
