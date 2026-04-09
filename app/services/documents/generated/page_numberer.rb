require "combine_pdf"

module Documents
  module Generated
    class PageNumberer
      COVER_VIEW_KEY = "cover_sheet".freeze
      SECTION_BREAK_VIEW_KEY = "section_break".freeze
      DEFAULT_TEXT_COLOR = "#000000".freeze
      LIGHT_TEXT_COLOR = "#ffffff".freeze

      class Error < StandardError; end

      def initialize(pdf_data:, entries:, overlay_renderer: PageNumberOverlayRenderer)
        @pdf_data = pdf_data
        @entries = Array(entries)
        @overlay_renderer = overlay_renderer
      end

      def call
        pdf = CombinePDF.parse(pdf_data)
        page_counts = resolve_page_counts(pdf.pages.count)
        page_index = 0

        entries.zip(page_counts).each do |entry, entry_page_count|
          entry_page_count.times do
            page = pdf.pages.fetch(page_index)
            absolute_page_number = page_index + 1

            unless cover_entry?(entry)
              page << render_overlay_page(
              page: page,
                page_label: "Pg. #{absolute_page_number}",
                page_text_color: page_text_color_for(entry)
              )
            end

            page_index += 1
          end
        end

        pdf.to_pdf
      end

      private

      attr_reader :pdf_data, :entries, :overlay_renderer

      def resolve_page_counts(total_pages)
        counts = entries.map { |entry| page_count_for(entry) }
        known_total = counts.compact.sum
        missing_indexes = counts.each_index.select { |index| counts[index].nil? }

        if missing_indexes.empty?
          validate_page_count_total!(known_total, total_pages)
          return counts
        end

        if missing_indexes.one?
          inferred_count = total_pages - known_total
          raise Error, "Unable to infer packet page counts for numbering" unless inferred_count.positive?

          counts[missing_indexes.first] = inferred_count
          validate_page_count_total!(counts.sum, total_pages)
          return counts
        end

        raise Error, "Unable to determine packet page counts for numbering"
      end

      def validate_page_count_total!(count_total, total_pages)
        return if count_total == total_pages

        raise Error, "Packet page counts (#{count_total}) did not match compiled PDF pages (#{total_pages})"
      end

      def page_count_for(entry)
        count =
          if entry.is_a?(Hash)
            entry[:page_count] || source_for(entry)&.cached_page_count
          elsif entry.respond_to?(:page_count) && entry.page_count.present?
            entry.page_count
          else
            source_for(entry)&.cached_page_count
          end

        count = count.to_i if count.present?
        count&.positive? ? count : nil
      end

      def cover_entry?(entry)
        source = source_for(entry)
        source.respond_to?(:html_view_key) && source.html_view_key == COVER_VIEW_KEY
      end

      def source_for(entry)
        return entry[:source] if entry.is_a?(Hash)
        return entry.source if entry.respond_to?(:source)

        entry
      end

      def render_overlay_page(page:, page_label:, page_text_color:)
        page_box = page[:CropBox] || page[:MediaBox] || [0, 0, 612, 792]
        width = page_box[2].to_f - page_box[0].to_f
        height = page_box[3].to_f - page_box[1].to_f

        overlay_renderer.new(
          page_label: page_label,
          page_width_points: width,
          page_height_points: height,
          page_text_color: page_text_color
        ).call
      end

      def page_text_color_for(entry)
        source = source_for(entry)
        return LIGHT_TEXT_COLOR if source.respond_to?(:html_view_key) && source.html_view_key == SECTION_BREAK_VIEW_KEY

        DEFAULT_TEXT_COLOR
      end
    end
  end
end
