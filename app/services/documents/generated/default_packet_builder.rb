module Documents
  module Generated
    class DefaultPacketBuilder
      Result = Struct.new(:groups, :packets, keyword_init: true) do
        def summary_message
          parts = []
          parts << "#{groups.count} default group#{'s' if groups.count != 1}" if groups.any?
          parts << "#{packets.count} default packet#{'s' if packets.count != 1}" if packets.any?
          return "All default groups and packets already exist." if parts.empty?

          "Added #{parts.join(' and ')}."
        end
      end

      DEFAULT_GROUPS = [
        {
          title: "Event Information",
          entries: [
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:event_overview] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:vendor_contacts] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:planning_team] }
          ]
        },
        {
          title: "Rentals & Decor",
          entries: []
        },
        {
          title: "Seating",
          entries: []
        },
        {
          title: "Contracts",
          entries: []
        }
      ].freeze

      DEFAULT_PACKETS = [
        {
          title: "Pineapple Productions Packet",
          entries: [
            { type: :page, view_key: "cover_sheet" },
            { type: :group, title: "Event Information" },
            { type: :page, view_key: "section_break", title: "Timelines" },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:run_of_show] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:production_timeline] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:hair_makeup_timeline] },
            { type: :group, title: "Rentals & Decor" },
            { type: :group, title: "Seating" }
          ]
        },
        {
          title: "Vendor Packet",
          entries: [
            { type: :page, view_key: "cover_sheet" },
            { type: :group, title: "Event Information" },
            { type: :page, view_key: "section_break", title: "Timelines" },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:run_of_show] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:production_timeline] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:hair_makeup_timeline] },
            { type: :group, title: "Rentals & Decor" }
          ]
        },
        {
          title: "Catering Packet",
          entries: [
            { type: :page, view_key: "cover_sheet" },
            { type: :group, title: "Event Information" },
            { type: :page, view_key: "section_break", title: "Timelines" },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:run_of_show] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:production_timeline] },
            { type: :group, title: "Rentals & Decor" },
            { type: :group, title: "Seating" }
          ]
        },
        {
          title: "Family Packet",
          entries: [
            { type: :page, view_key: "cover_sheet" },
            { type: :group, title: "Event Information" },
            { type: :page, view_key: "section_break", title: "Timelines" },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:family_timeline] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:hair_makeup_timeline] },
            { type: :group, title: "Rentals & Decor" },
            { type: :group, title: "Seating" }
          ]
        },
        {
          title: "Photo Packet",
          entries: [
            { type: :page, view_key: "cover_sheet" },
            { type: :group, title: "Event Information" },
            { type: :page, view_key: "section_break", title: "Timelines" },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:photo_video_timeline] },
            { type: :group, title: "Rentals & Decor" }
          ]
        }
      ].freeze

      def initialize(event:, built_by_user:)
        @event = event
        @built_by_user = built_by_user
      end

      def call
        GeneratedPacketSource.ensure_canonical_sources_for_event!(event)

        created_groups = seed_default_groups
        created_packets = seed_default_packets

        Result.new(groups: created_groups, packets: created_packets)
      end

      private

      attr_reader :event, :built_by_user

      def seed_default_groups
        DEFAULT_GROUPS.filter_map do |definition|
          existing_group = find_default_group(definition[:title])
          default_group_source_for(existing_group) if existing_group
          next if existing_group

          build_group(definition)
        end
      end

      def seed_default_packets
        existing_titles = event.documents.generated.packet_containers.where(storage_uri: nil).pluck(:title).map { |title| title.to_s.downcase }

        DEFAULT_PACKETS.filter_map do |definition|
          next if existing_titles.include?(definition[:title].downcase)

          packet = build_packet(definition)
          existing_titles << definition[:title].downcase
          packet
        end
      end

      def build_group(definition)
        result = GroupBuilder.new(event: event, title: definition[:title], built_by_user: built_by_user).call
        @default_group_sources ||= {}
        @default_group_sources[definition[:title].downcase] = result.source

        definition.fetch(:entries).each_with_index do |entry, index|
          result.document.packet_placements.create!(
            source: resolve_source(result.document, entry),
            position: index + 2
          )
        end

        result.document
      end

      def build_packet(definition)
        packet = event.documents.create!(
          title: definition[:title],
          doc_kind: Document::DOC_KINDS[:generated],
          client_visible: false,
          packets_portal_visible: false,
          is_template: false,
          is_latest: false,
          built_by_user: built_by_user,
          source: "packet",
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )

        definition[:entries].each_with_index do |entry, index|
          packet.packet_placements.create!(
            source: resolve_source(packet, entry),
            position: index + 1
          )
        end

        packet
      end

      def resolve_source(container_document, entry)
        case entry[:type]
        when :canonical
          GeneratedPacketSource.ensure_canonical!(event, entry[:key])
        when :page
          GeneratedPacketSource.build_page_source(
            event: event,
            view_key: entry[:view_key],
            title: entry[:title].presence || container_document.title,
            options: entry[:options] || {}
          ).tap(&:save!)
        when :group
          default_group_source_for(find_default_group(entry[:title]))
        else
          raise ArgumentError, "Unknown default packet entry type: #{entry[:type]}"
        end
      end

      def default_group_source_for(document)
        raise ArgumentError, "Missing default group document" unless document

        @default_group_sources ||= {}
        key = document.title.to_s.downcase
        @default_group_sources[key] ||= GeneratedPacketSource.find_or_create_group_source!(event, document)
      end

      def find_default_group(title)
        event.documents.generated.group_containers.where(storage_uri: nil)
             .where("packet_schema_version >= ?", Document::PACKET_SCHEMA_VERSIONS[:source_backed])
             .where(title: title)
             .order(:id)
             .first
      end
    end
  end
end
