module Documents
  module Generated
    class DefaultPacketBuilder
      DEFAULTS = [
        {
          title: "Family Packet",
          entries: [
            { type: :page, view_key: "cover_sheet" },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:event_overview] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:planning_team] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:family_timeline] }
          ]
        },
        {
          title: "Pineapple Productions Packet",
          entries: [
            { type: :page, view_key: "cover_sheet" },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:event_overview] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:planning_team] },
            { type: :canonical, key: GeneratedPacketSource::CANONICAL_KEYS[:run_of_show] }
          ]
        }
      ].freeze

      def initialize(event:, built_by_user:)
        @event = event
        @built_by_user = built_by_user
      end

      def call
        GeneratedPacketSource.ensure_canonical_sources_for_event!(event)

        existing_titles = event.documents.generated.where(storage_uri: nil).pluck(:title).map { |title| title.to_s.downcase }
        created_packets = []

        DEFAULTS.each do |definition|
          next if existing_titles.include?(definition[:title].downcase)

          packet = build_packet(definition)
          created_packets << packet
          existing_titles << definition[:title].downcase
        end

        created_packets
      end

      private

      attr_reader :event, :built_by_user

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

      def resolve_source(packet, entry)
        case entry[:type]
        when :canonical
          GeneratedPacketSource.ensure_canonical!(event, entry[:key])
        when :page
          GeneratedPacketSource.build_page_source(
            event: event,
            view_key: entry[:view_key],
            title: entry[:title].presence || packet.title,
            options: entry[:options] || {}
          ).tap(&:save!)
        else
          raise ArgumentError, "Unknown default packet entry type: #{entry[:type]}"
        end
      end
    end
  end
end
