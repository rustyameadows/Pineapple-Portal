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

        @source.update!(
          render_hash: current_hash,
          cached_pdf_key: "segments/current.pdf",
          cached_pdf_generated_at: Time.current,
          cached_page_count: 1,
          cached_file_size: 64
        )

        @document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
          working_manifest_hash: manifest_hash,
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:fresh]
        )
        @document.builds.create!(
          build_kind: DocumentBuild::BUILD_KINDS[:working],
          status: DocumentBuild::STATUSES[:succeeded],
          storage_uri: @document[:working_storage_uri],
          manifest_hash: manifest_hash,
          checksum_sha256: "working-sha",
          compiled_page_count: 1,
          file_size: 64,
          page_numbers: true,
          finished_at: Time.current
        )

        refresh_calls = []

        SegmentHasher.stub :call, ->(_source) { current_hash } do
          RunDocumentBuildJob.stub :perform_later, ->(build_id) { refresh_calls << build_id } do
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
          RunDocumentBuildJob.stub :perform_later, ->(build_id) { refresh_calls << build_id } do
            result = WorkingCopyAccess.new(definition_document: @document).call

            assert result.refreshing?
            assert_equal true, result.working_available
            assert_equal 1, refresh_calls.length
            assert_equal Document::WORKING_STATUSES[:refreshing], @document.reload.working_status
            assert_equal DocumentBuild::BUILD_KINDS[:working], @document.working_builds.recent_first.first.build_kind
          end
        end
      end

      test "returns refreshing without a viewer while the first live copy is building" do
        refresh_calls = []

        SegmentHasher.stub :call, ->(_source) { "hash-3" } do
          RunDocumentBuildJob.stub :perform_later, ->(build_id) { refresh_calls << build_id } do
            result = WorkingCopyAccess.new(definition_document: @document).call

            assert result.refreshing?
            assert_equal false, result.working_available
            assert_equal 1, refresh_calls.length
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
