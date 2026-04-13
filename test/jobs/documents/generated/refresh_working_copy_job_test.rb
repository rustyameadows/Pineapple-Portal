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

      test "delegates packet refreshes to WorkingCopyBuilder" do
        builder_calls = []

        WorkingCopyBuilder.stub :new, ->(**) {
          Struct.new(:calls) do
            def call
              calls << true
            end
          end.new(builder_calls)
        } do
          RefreshWorkingCopyJob.perform_now(@document.id)
        end

        assert_equal [true], builder_calls
      end

      test "clears the working copy when there are no packet pages" do
        @document.packet_placements.destroy_all

        assert_difference("DocumentBuild.count", 0) do
          RefreshWorkingCopyJob.perform_now(@document.id)
        end

        assert_nil @document.reload[:working_storage_uri]
        assert_equal Document::WORKING_STATUSES[:missing], @document.working_status_key
      end
    end
  end
end
