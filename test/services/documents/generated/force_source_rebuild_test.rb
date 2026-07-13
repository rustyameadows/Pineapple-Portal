require "test_helper"

module Documents
  module Generated
    class ForceSourceRebuildTest < ActiveSupport::TestCase
      setup do
        @event = events(:one)
        @user = users(:one)

        @source = create_page_source("Shared Page")
        stamp_cached_render!(@source, "segments/shared.pdf")

        @direct_packet = create_packet("Direct Packet")
        @direct_packet.packet_placements.create!(source: @source, position: 1)

        @group = create_group("Shared Group")
        @group.packet_placements.create!(source: @source, position: 1)
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, @group)

        @indirect_packet = create_packet("Indirect Packet")
        @indirect_packet.packet_placements.create!(source: group_source, position: 1)

        @unrelated_source = create_page_source("Unrelated Page")
        stamp_cached_render!(@unrelated_source, "segments/unrelated.pdf")
        @unrelated_packet = create_packet("Unrelated Packet")
        @unrelated_packet.packet_placements.create!(source: @unrelated_source, position: 1)

        [ @direct_packet, @indirect_packet, @unrelated_packet ].each do |packet|
          create_working_build(packet)
          create_snapshot_build(packet)
        end
      end

      test "clears the selected cache and every consumer working copy before enqueueing in deterministic order" do
        enqueued_ids = []

        result = WorkingCopyRefresh.stub :enqueue, ->(document) {
          enqueued_ids << document.id
          "queued-#{document.id}"
        } do
          ForceSourceRebuild.new(source: @source).call
        end

        expected_consumers = [ @direct_packet, @indirect_packet ].sort_by(&:id)
        expected_ids = expected_consumers.map(&:id)

        assert_equal expected_ids, result.consumers.map(&:id)
        assert_equal expected_ids.map { |id| "queued-#{id}" }, result.queued_builds
        assert_equal 2, result.consumer_count
        assert_equal expected_ids, enqueued_ids

        @source.reload
        assert_nil @source.render_hash
        assert_nil @source.cached_pdf_key
        assert_nil @source.cached_pdf_generated_at
        assert_nil @source.cached_page_count
        assert_nil @source.cached_file_size
        assert_nil @source.last_render_error

        expected_consumers.each do |packet|
          assert_equal 0, packet.reload.working_builds.count
          assert_equal 1, packet.snapshot_builds.count
          assert_equal Document::WORKING_STATUSES[:missing], packet.working_status
        end

        assert_equal "segments/unrelated.pdf", @unrelated_source.reload.cached_pdf_key
        assert_equal 1, @unrelated_packet.reload.working_builds.count
        assert_equal 1, @unrelated_packet.snapshot_builds.count
      end

      test "rejects a saved system page that is not cached" do
        source = create_page_source("Uncached Page")

        error = assert_raises(ForceSourceRebuild::Error) do
          ForceSourceRebuild.new(source: source).call
        end

        assert_equal "Only cached pages can be force built.", error.message
      end

      test "rejects uploaded PDFs even when they are cached" do
        source = @event.generated_packet_sources.create!(
          source_category: GeneratedPacketSource::CATEGORIES[:upload],
          kind: GeneratedPacketSource::KINDS[:pdf_asset],
          title: "Uploaded PDF",
          source_ref: { "logical_id" => SecureRandom.uuid },
          spec: { "label" => "Uploaded PDF", "kind" => GeneratedPacketSource::KINDS[:pdf_asset] }
        )
        stamp_cached_render!(source, "segments/upload.pdf")

        error = assert_raises(ForceSourceRebuild::Error) do
          ForceSourceRebuild.new(source: source).call
        end

        assert_equal "Only system-generated pages can be force built.", error.message
        assert_equal "segments/upload.pdf", source.reload.cached_pdf_key
      end

      test "rejects an unsaved page" do
        source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Unsaved Page",
          options: { "body_markdown" => "Draft" }
        )

        error = assert_raises(ForceSourceRebuild::Error) do
          ForceSourceRebuild.new(source: source).call
        end

        assert_equal "Force builds require a saved page.", error.message
      end

      test "does not clear a cached page that has no packet consumers" do
        source = create_page_source("Unused Page")
        stamp_cached_render!(source, "segments/unused.pdf")

        error = assert_raises(ForceSourceRebuild::Error) do
          ForceSourceRebuild.new(source: source).call
        end

        assert_equal "This page is not used by any packets.", error.message
        assert_equal "segments/unused.pdf", source.reload.cached_pdf_key
      end

      private

      def create_packet(title)
        @event.documents.create!(
          title: title,
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          client_visible: false,
          source: "packet",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )
      end

      def create_group(title)
        create_packet(title).tap do |document|
          document.update!(packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group])
        end
      end

      def create_page_source(title)
        GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: title,
          options: { "body_markdown" => title }
        ).tap(&:save!)
      end

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

      def create_working_build(document)
        document.builds.create!(
          build_kind: DocumentBuild::BUILD_KINDS[:working],
          status: DocumentBuild::STATUSES[:running],
          page_numbers: true
        )
      end

      def create_snapshot_build(document)
        document.builds.create!(
          build_kind: DocumentBuild::BUILD_KINDS[:snapshot],
          status: DocumentBuild::STATUSES[:succeeded],
          page_numbers: true,
          storage_uri: "documents/#{document.logical_id}/snapshot.pdf",
          manifest_hash: "snapshot-manifest",
          checksum_sha256: "snapshot-sha",
          compiled_page_count: 1,
          file_size: 128,
          finished_at: Time.current
        )
      end
    end
  end
end
