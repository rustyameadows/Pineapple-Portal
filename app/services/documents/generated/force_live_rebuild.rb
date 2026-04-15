module Documents
  module Generated
    class ForceLiveRebuild
      def initialize(definition_document:)
        @definition_document = definition_document
      end

      def call
        raise ArgumentError, "Live rebuilds are only available for packet definitions." unless definition_document&.packet_container?

        Document.transaction do
          leaf_sources.each(&:clear_cached_render!)
          definition_document.clear_working_copy!
        end

        WorkingCopyRefresh.enqueue(definition_document)
      end

      private

      attr_reader :definition_document

      def leaf_sources
        @leaf_sources ||= if definition_document.packet_source_backed? || definition_document.packet_placements.exists?
          ContainerEntries.new(definition_document: definition_document).call.filter_map do |entry|
            source = entry.source
            source unless source.group?
          end.uniq
        else
          []
        end
      end
    end
  end
end
