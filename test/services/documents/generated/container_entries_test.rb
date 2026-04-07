require "test_helper"

module Documents
  module Generated
    class ContainerEntriesTest < ActiveSupport::TestCase
      setup do
        @event = events(:one)
        @packet = @event.documents.create!(
          title: "Family Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          source: "packet",
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
          packet_container_kind: Document::PACKET_CONTAINER_KINDS[:packet]
        )
        @group = @event.documents.create!(
          title: "Design & Decor",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          source: "packet",
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
          packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
        )

        @page_one = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Welcome",
          options: { "body_markdown" => "One" }
        ).tap(&:save!)
        @group_page = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: "section_break",
          title: "Design & Decor",
          options: {}
        ).tap(&:save!)
        @group_source = GeneratedPacketSource.find_or_create_group_source!(@event, @group)

        @group.packet_placements.create!(source: @group_page, position: 1)
        @packet.packet_placements.create!(source: @page_one, position: 1)
        @group_placement = @packet.packet_placements.create!(source: @group_source, position: 2)
      end

      test "expands group placements into ordered leaf entries" do
        entries = ContainerEntries.new(definition_document: @packet).call

        assert_equal 2, entries.size
        assert_equal @page_one.id, entries.first.source.id
        assert_equal @group_page.id, entries.second.source.id
        assert_equal "placement:#{@group_placement.id}/placement:#{@group.packet_placements.first.id}", entries.second.entry_key
        assert_equal @group_placement.id, entries.second.top_level_placement.id
      end
    end
  end
end
