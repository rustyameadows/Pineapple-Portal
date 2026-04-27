require "test_helper"

module Documents
  module Generated
    class UploadedDocumentResolverTest < ActiveSupport::TestCase
      setup do
        @event = events(:one)
        @logical_id = SecureRandom.uuid
        @pinned_document = create_uploaded_pdf(version: 1, logical_id: @logical_id, title: "Pinned PDF")
        @source = GeneratedPacketSource.find_or_create_upload_source!(@event, @pinned_document, title: "Pinned PDF")
      end

      test "resolves the newest uploaded document version for the same logical id" do
        newer_document = create_uploaded_pdf(version: 2, logical_id: @logical_id, title: "Pinned PDF")

        resolved = UploadedDocumentResolver.new(@source).call

        assert_equal newer_document.id, resolved.id
        assert_not_equal @pinned_document.id, resolved.id
      end

      test "uses the newest uploaded document even when the original record still exists" do
        newer_document = create_uploaded_pdf(version: 2, logical_id: @logical_id, title: "Pinned PDF")

        resolved = UploadedDocumentResolver.new(@source).call

        assert_equal newer_document.id, resolved.id
      end

      private

      def create_uploaded_pdf(version:, logical_id:, title:)
        @event.documents.create!(
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
