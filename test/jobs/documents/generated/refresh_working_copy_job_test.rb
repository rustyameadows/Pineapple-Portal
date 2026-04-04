require "test_helper"

module Documents
  module Generated
    class RefreshWorkingCopyJobTest < ActiveJob::TestCase
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

        @stale_source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Needs Refresh",
          options: { "body_markdown" => "Hello" }
        ).tap(&:save!)

        @fresh_source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Already Fresh",
          options: { "body_markdown" => "World" }
        ).tap do |source|
          source.save!
          source.update!(
            render_hash: "fresh-hash",
            cached_pdf_key: "segments/fresh.pdf",
            cached_pdf_generated_at: Time.current,
            cached_page_count: 1,
            cached_file_size: 64
          )
        end

        GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: @stale_source,
          position: 1
        )
        GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: @fresh_source,
          position: 2
        )
      end

      test "rerenders only stale sources and rebuilds the working copy when the manifest changes" do
        rendered_source_ids = []
        builder_calls = []
        renderer_result = SegmentRenderer::Result.new(
          render_hash: "new-hash",
          storage_key: "segments/new.pdf",
          page_count: 2,
          file_size: 128,
          generated_at: Time.current,
          error: nil
        )

        first_manifest = Struct.new(:stale_sources, :manifest_hash).new([@stale_source], "manifest-before")
        second_manifest = Struct.new(:stale_sources, :manifest_hash).new([], "manifest-after")

        PacketManifest.stub :new, sequential_manifest_stub(first_manifest, second_manifest) do
          SegmentRenderer.stub :new, ->(source) {
            rendered_source_ids << source.id
            Struct.new(:result) do
              def call
                result
              end
            end.new(renderer_result)
          } do
            WorkingCopyBuilder.stub :new, ->(**) {
              Struct.new(:calls) do
                def call
                  calls << true
                end
              end.new(builder_calls)
            } do
              RefreshWorkingCopyJob.perform_now(@document.id)
            end
          end
        end

        assert_equal [@stale_source.id], rendered_source_ids
        assert_equal [true], builder_calls
        assert_equal "new-hash", @stale_source.reload.render_hash
        assert_equal "fresh-hash", @fresh_source.reload.render_hash
        assert_equal Document::WORKING_STATUSES[:fresh], @document.reload.working_status
      end

      test "skips rebuilding the working copy when the manifest is already current" do
        rendered_source_ids = []
        builder_calls = []
        @document.update!(
          working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
          working_manifest_hash: "manifest-current",
          working_rendered_at: Time.current,
          working_status: Document::WORKING_STATUSES[:refreshing]
        )

        manifest = Struct.new(:stale_sources, :manifest_hash).new([], "manifest-current")

        PacketManifest.stub :new, sequential_manifest_stub(manifest, manifest) do
          SegmentRenderer.stub :new, ->(source) {
            rendered_source_ids << source.id
            raise "renderer should not be called"
          } do
            WorkingCopyBuilder.stub :new, ->(**) {
              Struct.new(:calls) do
                def call
                  calls << true
                end
              end.new(builder_calls)
            } do
              RefreshWorkingCopyJob.perform_now(@document.id)
            end
          end
        end

        assert_equal [], rendered_source_ids
        assert_equal [], builder_calls
        assert_equal Document::WORKING_STATUSES[:fresh], @document.reload.working_status
      end

      private

      def sequential_manifest_stub(*results)
        queue = results.flatten.dup

        lambda do |**|
          Struct.new(:result) do
            def call
              result
            end
          end.new(queue.shift)
        end
      end
    end
  end
end
