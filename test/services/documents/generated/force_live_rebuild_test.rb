require "test_helper"

module Documents
  module Generated
    class ForceLiveRebuildTest < ActiveSupport::TestCase
      setup do
        @event = events(:one)
        @user = users(:one)

        @document = @event.documents.create!(
          title: "Generated Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          client_visible: false,
          source: "packet",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )

        @direct_source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Notes",
          options: { "body_markdown" => "Hello" }
        ).tap(&:save!)

        GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: @direct_source,
          position: 1
        )

        @group_document = @event.documents.create!(
          title: "Shared Group",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          client_visible: false,
          source: "packet",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
          packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
        )

        @group_child_source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Group Notes",
          options: { "body_markdown" => "Nested" }
        ).tap(&:save!)

        GeneratedPacketPlacement.create!(
          document_logical_id: @group_document.logical_id,
          source: @group_child_source,
          position: 1
        )

        @group_source = GeneratedPacketSource.find_or_create_group_source!(@event, @group_document)

        GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: @group_source,
          position: 2
        )

        @unrelated_source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Unrelated",
          options: { "body_markdown" => "Keep me" }
        ).tap(&:save!)
      end

      test "clears working state and leaf source caches before enqueueing a fresh rebuild" do
        stamp_cached_render!(@direct_source, "segments/direct.pdf")
        stamp_cached_render!(@group_child_source, "segments/group-child.pdf")
        stamp_cached_render!(@unrelated_source, "segments/unrelated.pdf")

        @document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/live.pdf",
          working_manifest_hash: "working-manifest",
          working_checksum_sha256: "working-sha",
          working_page_count: 4,
          working_file_size: 2048,
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:fresh]
        )

        @document.builds.create!(
          build_kind: DocumentBuild::BUILD_KINDS[:working],
          status: DocumentBuild::STATUSES[:running],
          page_numbers: true
        )
        @document.builds.create!(
          build_kind: DocumentBuild::BUILD_KINDS[:working],
          status: DocumentBuild::STATUSES[:succeeded],
          page_numbers: true,
          storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/old-live.pdf",
          manifest_hash: "old-manifest",
          checksum_sha256: "old-sha",
          compiled_page_count: 3,
          file_size: 1024,
          finished_at: Time.current
        )
        snapshot_build = @document.builds.create!(
          build_kind: DocumentBuild::BUILD_KINDS[:snapshot],
          status: DocumentBuild::STATUSES[:succeeded],
          page_numbers: true,
          storage_uri: "documents/#{@event.id}/#{@document.logical_id}/snapshots/v1.pdf",
          manifest_hash: "snapshot-manifest",
          checksum_sha256: "snapshot-sha",
          compiled_page_count: 3,
          file_size: 1024,
          finished_at: Time.current
        )

        enqueued_documents = []

        WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_documents << document.logical_id; true } do
          ForceLiveRebuild.new(definition_document: @document).call
        end

        assert_equal [@document.logical_id], enqueued_documents

        @direct_source.reload
        @group_child_source.reload
        @unrelated_source.reload
        @document.reload

        assert_nil @direct_source.render_hash
        assert_nil @direct_source.cached_pdf_key
        assert_nil @group_child_source.render_hash
        assert_nil @group_child_source.cached_pdf_key

        assert_equal "rendered-hash", @unrelated_source.render_hash
        assert_equal "segments/unrelated.pdf", @unrelated_source.cached_pdf_key

        assert_nil @document.working_storage_uri
        assert_nil @document.working_manifest_hash
        assert_equal Document::WORKING_STATUSES[:missing], @document.working_status
        assert_equal 0, @document.working_builds.count
        assert_equal [snapshot_build.id], @document.snapshot_builds.pluck(:id)
      end

      private

      def stamp_cached_render!(source, storage_key)
        source.update!(
          render_hash: "rendered-hash",
          cached_pdf_key: storage_key,
          cached_pdf_generated_at: Time.current,
          cached_page_count: 1,
          cached_file_size: 128,
          last_render_error: "old error"
        )
      end
    end
  end
end
