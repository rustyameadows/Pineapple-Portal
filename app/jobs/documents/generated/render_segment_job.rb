module Documents
  module Generated
    class RenderSegmentJob < ApplicationJob
      queue_as :default

      def perform(segment_id)
        segment = DocumentSegment.find(segment_id)
        renderer = SegmentRenderer.new(segment)
        result = renderer.call

        if result.error.present?
          segment.update(
            last_render_error: result.error,
            render_hash: nil,
            cached_pdf_key: nil,
            cached_pdf_generated_at: nil,
            cached_page_count: nil,
            cached_file_size: nil
          )
        else
          segment.update(
            render_hash: result.render_hash,
            cached_pdf_key: result.storage_key,
            cached_pdf_generated_at: result.generated_at,
            cached_page_count: result.page_count,
            cached_file_size: result.file_size,
            last_render_error: nil
          )
        end
      end
    end
  end
end
