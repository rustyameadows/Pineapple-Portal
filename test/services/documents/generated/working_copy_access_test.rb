require "test_helper"

module Documents
  module Generated
    class WorkingCopyAccessTest < ActiveSupport::TestCase
      setup do
        @event = events(:one)
        @document = @event.documents.create!(
          title: "Generated Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          client_visible: false,
          source: "packet",
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )

        @source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Notes",
          options: { "body_markdown" => "Hello" }
        ).tap(&:save!)

        @placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: @source,
          position: 1
        )
      end

      test "returns fresh without enqueue when the working manifest matches" do
        current_hash = "hash-1"
        manifest_hash = placement_manifest_hash(@placement, current_hash)

        @document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
          working_manifest_hash: manifest_hash,
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:fresh]
        )

        refresh_calls = []

        SegmentHasher.stub :call, ->(_source) { current_hash } do
          RefreshWorkingCopyJob.stub :perform_later, ->(document_id) { refresh_calls << document_id } do
            result = WorkingCopyAccess.new(definition_document: @document).call

            assert result.fresh?
            assert_equal [], refresh_calls
          end
        end
      end

      test "returns refreshing and enqueues when a live copy is stale" do
        @document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
          working_manifest_hash: "outdated-manifest",
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:fresh]
        )

        refresh_calls = []

        SegmentHasher.stub :call, ->(_source) { "hash-2" } do
          RefreshWorkingCopyJob.stub :perform_later, ->(document_id) { refresh_calls << document_id } do
            result = WorkingCopyAccess.new(definition_document: @document).call

            assert result.refreshing?
            assert_equal true, result.working_available
            assert_equal [@document.id], refresh_calls
            assert_equal Document::WORKING_STATUSES[:refreshing], @document.reload.working_status
          end
        end
      end

      test "returns refreshing without a viewer while the first live copy is building" do
        refresh_calls = []

        SegmentHasher.stub :call, ->(_source) { "hash-3" } do
          RefreshWorkingCopyJob.stub :perform_later, ->(document_id) { refresh_calls << document_id } do
            result = WorkingCopyAccess.new(definition_document: @document).call

            assert result.refreshing?
            assert_equal false, result.working_available
            assert_equal [@document.id], refresh_calls
            assert_equal Document::WORKING_STATUSES[:refreshing], @document.reload.working_status
          end
        end
      end

      private

      def placement_manifest_hash(placement, render_hash)
        Digest::SHA256.hexdigest(JSON.dump([
          {
            entry_key: "placement:#{placement.id}",
            source_key: "#{placement.source.class.name}:#{placement.source.id}",
            render_hash: render_hash
          }
        ]))
      end
    end
  end
end
