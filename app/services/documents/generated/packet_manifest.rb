require "digest"

module Documents
  module Generated
    class PacketManifest
      Entry = Struct.new(:entry, :source, :render_hash, :stale, keyword_init: true)

      Result = Struct.new(:entries, :manifest_hash, keyword_init: true) do
        def empty?
          entries.empty?
        end

        def stale_entries
          entries.select(&:stale)
        end

        def stale_sources
          stale_entries.map(&:source).uniq
        end
      end

      def initialize(definition_document:)
        @definition_document = definition_document
      end

      def call
        analyzed_entries = ordered_entries.map do |entry|
          source = source_for(entry)
          render_hash = SegmentHasher.call(source)

          Entry.new(
            entry: entry,
            source: source,
            render_hash: render_hash,
            stale: source_stale?(source, render_hash)
          )
        end

        Result.new(
          entries: analyzed_entries,
          manifest_hash: Digest::SHA256.hexdigest(JSON.dump(manifest_payload(analyzed_entries)))
        )
      end

      private

      attr_reader :definition_document

      def ordered_entries
        if definition_document.packet_source_backed? || definition_document.packet_placements.exists?
          ContainerEntries.new(definition_document: definition_document).call
        else
          definition_document.segments.ordered.to_a
        end
      end

      def source_for(entry)
        entry.respond_to?(:source) ? entry.source : entry
      end

      def source_stale?(source, render_hash)
        !source.cached? || source.cache_stale?(render_hash)
      end

      def manifest_payload(entries)
        entries.map do |entry|
          {
            entry_key: entry_key_for(entry.entry),
            source_key: source_key_for(entry.source),
            render_hash: entry.render_hash
          }
        end
      end

      def entry_key_for(entry)
        return entry.entry_key if entry.respond_to?(:entry_key)

        if entry.respond_to?(:source)
          "placement:#{entry.id}"
        else
          "segment:#{entry.id}"
        end
      end

      def source_key_for(source)
        "#{source.class.name}:#{source.id}"
      end
    end
  end
end
