module Documents
  module Generated
    class PacketConsumerResolver
      def initialize(event:)
        @event = event
      end

      def for_source(source)
        logical_ids = direct_packet_logical_ids_for_source(source) + indirect_packet_logical_ids_for_source(source)
        packet_definitions.where(logical_id: logical_ids.uniq)
      end

      def for_container(document)
        return packet_definitions.none unless document&.group_container?

        group_source_ids = event.generated_packet_sources
                                .group_sources
                                .where("source_ref ->> 'logical_id' = ?", document.logical_id)
                                .pluck(:id)
        return packet_definitions.none if group_source_ids.empty?

        logical_ids = GeneratedPacketPlacement.where(generated_packet_source_id: group_source_ids)
                                              .pluck(:document_logical_id)
                                              .uniq
        packet_definitions.where(logical_id: logical_ids)
      end

      private

      attr_reader :event

      def packet_definitions
        event.documents.generated.packet_containers.where(storage_uri: nil)
      end

      def group_definitions
        event.documents.generated.group_containers.where(storage_uri: nil)
      end

      def direct_packet_logical_ids_for_source(source)
        source.packet_placements
              .where(document_logical_id: packet_definitions.select(:logical_id))
              .pluck(:document_logical_id)
      end

      def indirect_packet_logical_ids_for_source(source)
        return [] if source.group?

        group_logical_ids = source.packet_placements
                                  .where(document_logical_id: group_definitions.select(:logical_id))
                                  .pluck(:document_logical_id)
                                  .uniq
        return [] if group_logical_ids.empty?

        group_source_ids = event.generated_packet_sources.group_sources.where("source_ref ->> 'logical_id' IN (?)", group_logical_ids).pluck(:id)
        return [] if group_source_ids.empty?

        GeneratedPacketPlacement.where(generated_packet_source_id: group_source_ids, document_logical_id: packet_definitions.select(:logical_id))
                               .pluck(:document_logical_id)
      end
    end
  end
end
