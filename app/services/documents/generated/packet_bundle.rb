require "combine_pdf"
require "digest"

module Documents
  module Generated
    class PacketBundle
      PreparedEntries = Struct.new(:entries, :rendered_entries, :manifest_hash, keyword_init: true)
      Result = Struct.new(
        :entries,
        :manifest_hash,
        :pdf_data,
        :page_count,
        :file_size,
        :checksum_md5,
        :checksum_sha256,
        keyword_init: true
      )

      def initialize(definition_document:, segment_storage: R2Storage.new, page_numbers: false, check_cancelled: nil)
        @definition_document = definition_document
        @segment_storage = segment_storage
        @page_numbers = !!page_numbers
        @check_cancelled = check_cancelled || -> {}
      end

      def call
        prepared = prepare
        build_from_prepared(prepared)
      end

      def build_from_prepared(prepared)
        compiled_pdf = stitch_segments(prepared.rendered_entries)
        compiled_pdf = apply_page_numbers(compiled_pdf, prepared.rendered_entries) if page_numbers
        totals = derive_totals(compiled_pdf)

        Result.new(
          entries: prepared.entries,
          manifest_hash: prepared.manifest_hash,
          pdf_data: compiled_pdf,
          page_count: totals[:page_count],
          file_size: totals[:file_size],
          checksum_md5: totals[:checksum_md5],
          checksum_sha256: totals[:checksum_sha256]
        )
      end

      def prepare
        check_cancelled!
        entries = ordered_entries
        raise Compiler::CompileError, "No segments configured" if entries.empty?

        rendered_entries = entries.map do |entry|
          check_cancelled!
          ensure_cached(entry)
        end

        check_cancelled!

        PreparedEntries.new(
          entries: entries,
          rendered_entries: rendered_entries,
          manifest_hash: manifest_hash_for(rendered_entries)
        )
      end

      private

      attr_reader :definition_document, :segment_storage, :page_numbers

      def ordered_entries
        if definition_document.packet_source_backed? || definition_document.packet_placements.exists?
          ContainerEntries.new(definition_document: definition_document).call
        else
          definition_document.segments.ordered.to_a
        end
      end

      def ensure_cached(entry)
        source = source_for(entry)
        hash = SegmentHasher.call(source)

        if source.cached? && !source.cache_stale?(hash)
          return cache_entry(entry, source)
        end

        check_cancelled!
        result = SegmentRenderer.new(source).call
        if result.error.present?
          raise Compiler::CompileError, "Segment #{source.display_title.inspect} failed to render: #{result.error}"
        end

        source.update!(
          render_hash: result.render_hash,
          cached_pdf_key: result.storage_key,
          cached_pdf_generated_at: result.generated_at,
          cached_page_count: result.page_count,
          cached_file_size: result.file_size,
          last_render_error: nil
        )

        cache_entry(entry, source)
      end

      def cache_entry(entry, source)
        {
          entry: entry,
          source: source,
          render_hash: source.render_hash
        }
      end

      def manifest_hash_for(rendered_entries)
        manifest = rendered_entries.map do |entry|
          {
            entry_key: entry_key_for(entry[:entry]),
            source_key: source_key_for(source_for(entry[:entry])),
            render_hash: entry[:render_hash]
          }
        end

        Digest::SHA256.hexdigest(JSON.dump(manifest))
      end

      def stitch_segments(rendered_entries)
        combined_pdf = CombinePDF.new

        rendered_entries.each do |entry|
          check_cancelled!
          pdf_data = segment_storage.download(entry[:source].cached_pdf_key)
          raise Compiler::CompileError, "Cached PDF not found for #{entry[:source].display_title.inspect}" unless pdf_data

          buffer = pdf_data.respond_to?(:read) ? pdf_data.read : pdf_data
          buffer = buffer.to_s
          buffer.force_encoding(Encoding::BINARY)
          raise Compiler::CompileError, "Cached PDF empty for #{entry[:source].display_title.inspect}" if buffer.empty?

          parsed_pdf = CombinePDF.parse(buffer)
          entry[:page_count] = parsed_pdf.pages.count
          combined_pdf << parsed_pdf
        end

        combined_pdf.to_pdf
      end

      def apply_page_numbers(compiled_pdf, rendered_entries)
        PageNumberer.new(
          pdf_data: compiled_pdf,
          entries: rendered_entries
        ).call
      end

      def derive_totals(compiled_pdf)
        pdf = CombinePDF.parse(compiled_pdf)
        page_count = pdf.pages.count
        file_size = compiled_pdf.bytesize
        checksum_md5 = Digest::MD5.hexdigest(compiled_pdf)
        checksum_sha256 = Digest::SHA256.hexdigest(compiled_pdf)

        {
          page_count: page_count,
          file_size: file_size,
          checksum_md5: checksum_md5,
          checksum_sha256: checksum_sha256
        }
      end

      def source_for(entry)
        entry.respond_to?(:source) ? entry.source : entry
      end

      def placement_id_for(entry)
        entry.respond_to?(:source) ? entry.id : nil
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

      def check_cancelled!
        @check_cancelled.call
      end
    end
  end
end
