module Documents
  module Generated
    class PacketUsageMap
      Result = Struct.new(:source_packets, :upload_packets, :group_packets, keyword_init: true)

      def initialize(event:)
        @event = event
      end

      def call
        source_packets = Hash.new { |hash, key| hash[key] = [] }
        upload_packets = Hash.new { |hash, key| hash[key] = [] }
        group_packets = Hash.new { |hash, key| hash[key] = [] }

        packet_definitions.find_each do |packet|
          direct_placements(packet).each do |placement|
            source_packets[placement.source.id] << packet.title

            next unless placement.source.group?

            group_packets[placement.source.group_document_logical_id] << packet.title if placement.source.group_document_logical_id.present?
          end

          leaf_entries(packet).each do |entry|
            source_packets[entry.source.id] << packet.title

            next unless entry.source.pdf_asset? && entry.source.pdf_logical_id.present?

            upload_packets[entry.source.pdf_logical_id] << packet.title
          end
        end

        Result.new(
          source_packets: normalize(source_packets),
          upload_packets: normalize(upload_packets),
          group_packets: normalize(group_packets)
        )
      end

      private

      attr_reader :event

      def packet_definitions
        event.documents.generated.packet_containers.where(storage_uri: nil)
      end

      def direct_placements(packet)
        packet.packet_placements.includes(:source).ordered.to_a
      end

      def leaf_entries(packet)
        ContainerEntries.new(definition_document: packet).call
      end

      def normalize(hash)
        hash.transform_values { |values| values.compact.uniq.sort }
      end
    end
  end
end
