require "test_helper"

module Documents
  module Generated
    class WorkingCopyRefreshTest < ActiveSupport::TestCase
      self.use_transactional_tests = false

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

        GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: @source,
          position: 1
        )
      end

      teardown do
        DocumentBuild.where(document_id: @document.id).delete_all if @document&.id.present?
        GeneratedPacketPlacement.where(document_logical_id: @document.logical_id).delete_all if @document&.logical_id.present?
        GeneratedPacketSource.where(id: @source.id).delete_all if @source&.id.present?
        Document.where(id: @document.id).delete_all if @document&.id.present?
      end

      test "returns the existing active build without enqueueing another job" do
        existing_build = @document.builds.create!(
          status: DocumentBuild::STATUSES[:pending],
          build_kind: DocumentBuild::BUILD_KINDS[:working],
          page_numbers: true
        )

        enqueued_build_ids = []

        RunDocumentBuildJob.stub :perform_later, ->(build_id) { enqueued_build_ids << build_id } do
          result = WorkingCopyRefresh.enqueue(@document)

          assert_equal existing_build.id, result.id
          assert_equal [], enqueued_build_ids
        end
      end

      test "concurrent enqueue attempts create one working build and queue one job" do
        entered_lock = Queue.new
        release_lock = Queue.new
        enqueued_build_ids = Queue.new
        results = Queue.new
        paused_first_entry = false
        original_with_lock = @document.method(:with_lock)

        @document.define_singleton_method(:with_lock) do |&block|
          original_with_lock.call do
            unless paused_first_entry
              paused_first_entry = true
              entered_lock << true
              release_lock.pop
            end

            block.call
          end
        end

        RunDocumentBuildJob.stub :perform_later, ->(build_id) { enqueued_build_ids << build_id } do
          first = Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              results << WorkingCopyRefresh.enqueue(@document).id
            end
          end

          entered_lock.pop

          second = Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              results << WorkingCopyRefresh.enqueue(@document).id
            end
          end

          release_lock << true

          [first, second].each(&:join)
        end

        build_ids = 2.times.map { results.pop }
        queued_build_ids = []
        queued_build_ids << enqueued_build_ids.pop until enqueued_build_ids.empty?

        assert_equal 1, @document.reload.working_builds.count
        assert_equal 1, build_ids.uniq.count
        assert_equal 1, queued_build_ids.count
        assert_equal build_ids.first, queued_build_ids.first
      end

      test "stale active working builds are failed and replaced with a retry build" do
        stale_build = @document.builds.create!(
          status: DocumentBuild::STATUSES[:running],
          build_kind: DocumentBuild::BUILD_KINDS[:working],
          page_numbers: true,
          progress_stage: DocumentBuild::PROGRESS_STAGES[:rendering_entries],
          progress_message: "Rendering pages 1/1: Notes",
          progress_current: 1,
          progress_total: 1,
          last_progress_at: 11.minutes.ago,
          started_at: 11.minutes.ago
        )

        enqueued_build_ids = []

        RunDocumentBuildJob.stub :perform_later, ->(build_id) { enqueued_build_ids << build_id } do
          result = WorkingCopyRefresh.enqueue(@document)

          assert_equal DocumentBuild::STATUSES[:pending], result.status
          assert_equal "Retrying live PDF after a stalled render", result.reload.progress_message
          assert_equal [result.id], enqueued_build_ids
          assert_equal DocumentBuild::STATUSES[:failed], stale_build.reload.status
          assert_match(/stalled after 10 minutes/, stale_build.error_message)
        end
      end
    end
  end
end
