module Documents
  module Generated
    class ContainerEntries
      ResolvedEntry = Struct.new(
        :placement,
        :source,
        :entry_key,
        :top_level_placement,
        :group_source,
        :group_document,
        keyword_init: true
      ) do
        def grouped?
          group_source.present?
        end

        def top_level_source
          top_level_placement&.source
        end
      end

      def initialize(definition_document:)
        @definition_document = definition_document
      end

      def call
        top_level_placements.flat_map do |placement|
          expand_placement(placement)
        end
      end

      private

      attr_reader :definition_document

      def top_level_placements
        definition_document.packet_placements.includes(:source).ordered.to_a
      end

      def expand_placement(placement)
        source = placement.source
        return [leaf_entry(placement:, source:, entry_key: placement_key(placement), top_level_placement: placement)] unless source.group?

        group_document = source.group_document
        return [] unless group_document

        group_document.packet_placements.includes(:source).ordered.map do |child_placement|
          leaf_entry(
            placement: child_placement,
            source: child_placement.source,
            entry_key: "#{placement_key(placement)}/#{placement_key(child_placement)}",
            top_level_placement: placement,
            group_source: source,
            group_document: group_document
          )
        end
      end

      def leaf_entry(placement:, source:, entry_key:, top_level_placement:, group_source: nil, group_document: nil)
        ResolvedEntry.new(
          placement: placement,
          source: source,
          entry_key: entry_key,
          top_level_placement: top_level_placement,
          group_source: group_source,
          group_document: group_document
        )
      end

      def placement_key(placement)
        "placement:#{placement.id}"
      end
    end
  end
end
