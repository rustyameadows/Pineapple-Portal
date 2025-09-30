module Documents
  module Generated
    class R2Storage
      SEGMENT_PREFIX = "segments".freeze

      def initialize(adapter: default_adapter)
        @adapter = adapter
      end

      def upload_segment(hash, data, content_type: "application/pdf")
        key = segment_key(hash)
        adapter.upload_io(key, data, content_type: content_type)
        key
      end

      def download(path)
        io = adapter.download(path)
        io&.rewind
        io&.read
      end

      def presigned_download_url(path, expires_in: 15.minutes)
        adapter.presigned_download_url(key: path, expires_in: expires_in)
      end

      def segment_key(hash)
        File.join(SEGMENT_PREFIX, "#{hash}.pdf")
      end

      private

      attr_reader :adapter

      def default_adapter
        R2::Storage.new
      end
    end
  end
end
