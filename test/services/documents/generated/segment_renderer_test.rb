require "test_helper"

module Documents
  module Generated
    class SegmentRendererTest < ActiveSupport::TestCase
      class StorageStub
        attr_reader :downloaded_key, :uploaded_data

        def initialize(downloads)
          @downloads = downloads
        end

        def download(key)
          @downloaded_key = key
          @downloads[key]
        end

        def upload_segment(hash, data)
          @uploaded_data = data
          "segments/#{hash}.pdf"
        end
      end

      test "renders the replacement uploaded pdf for a packet source" do
        event = events(:one)
        logical_id = SecureRandom.uuid
        original_pdf = create_uploaded_pdf(event: event, version: 1, logical_id: logical_id, title: "Design Deck")
        replacement_pdf = create_uploaded_pdf(event: event, version: 2, logical_id: logical_id, title: "Design Deck")
        source = GeneratedPacketSource.find_or_create_upload_source!(event, original_pdf, title: "Design Deck")
        storage = StorageStub.new(
          original_pdf.storage_uri => "ORIGINAL_PDF",
          replacement_pdf.storage_uri => "REPLACEMENT_PDF"
        )
        reader = Struct.new(:page_count).new(8)

        PDF::Reader.stub :new, ->(_io) { reader } do
          result = SegmentRenderer.new(source, storage: storage).call

          assert_nil result.error
          assert_equal replacement_pdf.storage_uri, storage.downloaded_key
          assert_equal "REPLACEMENT_PDF", storage.uploaded_data
          assert_equal 8, result.page_count
        end
      end

      private

      def create_uploaded_pdf(event:, version:, logical_id:, title:)
        event.documents.create!(
          title: title,
          doc_kind: Document::DOC_KINDS[:uploaded],
          logical_id: logical_id,
          version: version,
          is_latest: true,
          source: "staff_upload",
          storage_uri: "documents/#{logical_id}/#{version}.pdf",
          checksum: "#{logical_id}-#{version}-checksum",
          checksum_sha256: SecureRandom.hex(32),
          size_bytes: 1024,
          content_type: "application/pdf",
          built_by_user: users(:one)
        )
      end
    end
  end
end
