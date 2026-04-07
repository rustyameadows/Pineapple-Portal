require "test_helper"

module Documents
  module Generated
    class PacketConsumerResolverTest < ActiveSupport::TestCase
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

        @group_page = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: "section_break",
          title: "Design & Decor",
          options: {}
        ).tap(&:save!)
        @group.packet_placements.create!(source: @group_page, position: 1)

        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, @group)
        @packet.packet_placements.create!(source: group_source, position: 1)
      end

      test "finds packet consumers for a leaf source used through a group" do
        packets = PacketConsumerResolver.new(event: @event).for_source(@group_page)

        assert_equal [@packet.logical_id], packets.pluck(:logical_id)
      end

      test "finds packet consumers for a group container" do
        packets = PacketConsumerResolver.new(event: @event).for_container(@group)

        assert_equal [@packet.logical_id], packets.pluck(:logical_id)
      end
    end
  end
end
