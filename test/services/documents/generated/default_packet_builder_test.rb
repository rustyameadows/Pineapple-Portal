require "test_helper"

module Documents
  module Generated
    class DefaultPacketBuilderTest < ActiveSupport::TestCase
      fixtures :events, :users

      setup do
        @event = events(:one)
        @built_by_user = users(:one)
      end

      test "creates default groups before packets with the expected contents and shared sources" do
        result = DefaultPacketBuilder.new(event: @event, built_by_user: @built_by_user).call

        assert_equal ["Contracts", "Event Information", "Rentals & Decor", "Seating"], result.groups.map(&:title).sort
        assert_equal ["Catering Packet", "Family Packet", "Photo Packet", "Pineapple Productions Packet", "Vendor Packet"], result.packets.map(&:title).sort

        event_information = @event.documents.generated.group_containers.where(storage_uri: nil).find_by!(title: "Event Information")
        rentals = @event.documents.generated.group_containers.where(storage_uri: nil).find_by!(title: "Rentals & Decor")
        seating = @event.documents.generated.group_containers.where(storage_uri: nil).find_by!(title: "Seating")
        contracts = @event.documents.generated.group_containers.where(storage_uri: nil).find_by!(title: "Contracts")

        assert_equal [
          [:page, "section_break", "Event Information"],
          [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:event_overview]],
          [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:vendor_contacts]],
          [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:planning_team]]
        ], placement_signatures_for(event_information)

        assert_equal [[:page, "section_break", "Rentals & Decor"]], placement_signatures_for(rentals)
        assert_equal [[:page, "section_break", "Seating"]], placement_signatures_for(seating)
        assert_equal [[:page, "section_break", "Contracts"]], placement_signatures_for(contracts)

        assert_equal expected_packet_signatures("Pineapple Productions Packet"), placement_signatures_for(packet_definition("Pineapple Productions Packet"))
        assert_equal expected_packet_signatures("Vendor Packet"), placement_signatures_for(packet_definition("Vendor Packet"))
        assert_equal expected_packet_signatures("Catering Packet"), placement_signatures_for(packet_definition("Catering Packet"))
        assert_equal expected_packet_signatures("Family Packet"), placement_signatures_for(packet_definition("Family Packet"))
        assert_equal expected_packet_signatures("Photo Packet"), placement_signatures_for(packet_definition("Photo Packet"))

        event_information_source = GeneratedPacketSource.find_or_create_group_source!(@event, event_information)
        rentals_source = GeneratedPacketSource.find_or_create_group_source!(@event, rentals)
        seating_source = GeneratedPacketSource.find_or_create_group_source!(@event, seating)

        assert_equal 5, GeneratedPacketPlacement.where(source: event_information_source).count
        assert_equal 5, GeneratedPacketPlacement.where(source: rentals_source).count
        assert_equal 3, GeneratedPacketPlacement.where(source: seating_source).count
      end

      test "reuses an existing same titled group without mutating it" do
        result = GroupBuilder.new(event: @event, title: "Seating", built_by_user: @built_by_user).call
        custom_source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Custom Seating Notes",
          options: { "body_markdown" => "Keep this content" }
        )
        custom_source.save!
        result.document.packet_placements.create!(source: custom_source, position: 2)
        original_signatures = placement_signatures_for(result.document)

        build_result = DefaultPacketBuilder.new(event: @event, built_by_user: @built_by_user).call

        assert_not_includes build_result.groups.map(&:title), "Seating"
        assert_equal 1, @event.documents.generated.group_containers.where(storage_uri: nil, title: "Seating").count
        assert_equal original_signatures, placement_signatures_for(result.document.reload)

        seating_source = GeneratedPacketSource.find_or_create_group_source!(@event, result.document)
        assert_equal 3, GeneratedPacketPlacement.where(source: seating_source).count
      end

      test "skips existing packet titles without mutating them" do
        packet = create_packet_definition("Family Packet")
        existing_source = GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Keep Existing Family Packet",
          options: { "body_markdown" => "Do not overwrite" }
        )
        existing_source.save!
        packet.packet_placements.create!(source: existing_source, position: 1)

        result = DefaultPacketBuilder.new(event: @event, built_by_user: @built_by_user).call

        assert_equal ["Catering Packet", "Photo Packet", "Pineapple Productions Packet", "Vendor Packet"], result.packets.map(&:title).sort
        assert_equal [[:page, DocumentSegment::TEXT_PAGE_VIEW_KEY, "Keep Existing Family Packet"]], placement_signatures_for(packet.reload)
      end

      test "creates missing groups even when all default packets already exist" do
        DefaultPacketBuilder::DEFAULT_PACKETS.each do |definition|
          create_packet_definition(definition[:title])
        end

        result = DefaultPacketBuilder.new(event: @event, built_by_user: @built_by_user).call

        assert_equal [], result.packets
        assert_equal ["Contracts", "Event Information", "Rentals & Decor", "Seating"], result.groups.map(&:title).sort
      end

      private

      def packet_definition(title)
        @event.documents.generated.packet_containers.where(storage_uri: nil).find_by!(title: title)
      end

      def create_packet_definition(title)
        @event.documents.create!(
          title: title,
          doc_kind: Document::DOC_KINDS[:generated],
          client_visible: false,
          packets_portal_visible: false,
          is_template: false,
          is_latest: false,
          built_by_user: @built_by_user,
          source: "packet",
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )
      end

      def placement_signatures_for(document)
        document.packet_placements.order(:position).map do |placement|
          source_signature(placement.source)
        end
      end

      def source_signature(source)
        return [:group, source.display_title] if source.group?
        return [:canonical, source.canonical_key] if source.canonical?

        [:page, source.html_view_key, source.title]
      end

      def expected_packet_signatures(title)
        signatures = [
          [:page, "cover_sheet", title],
          [:group, "Event Information"],
          [:page, "section_break", "Timelines"]
        ]

        case title
        when "Pineapple Productions Packet"
          signatures + [
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:run_of_show]],
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:production_timeline]],
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference]],
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:hair_makeup_timeline]],
            [:group, "Rentals & Decor"],
            [:group, "Seating"]
          ]
        when "Vendor Packet"
          signatures + [
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:run_of_show]],
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:production_timeline]],
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:hair_makeup_timeline]],
            [:group, "Rentals & Decor"]
          ]
        when "Catering Packet"
          signatures + [
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:run_of_show]],
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:production_timeline]],
            [:group, "Rentals & Decor"],
            [:group, "Seating"]
          ]
        when "Family Packet"
          signatures + [
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:family_timeline]],
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference]],
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:hair_makeup_timeline]],
            [:group, "Rentals & Decor"],
            [:group, "Seating"]
          ]
        when "Photo Packet"
          signatures + [
            [:canonical, GeneratedPacketSource::CANONICAL_KEYS[:photo_video_timeline]],
            [:group, "Rentals & Decor"]
          ]
        else
          raise ArgumentError, "Unexpected packet title: #{title}"
        end
      end
    end
  end
end
