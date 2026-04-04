module Documents
  module Generated
    class RefreshWorkingCopyJob < ApplicationJob
      queue_as :default

      def perform(document_id)
        definition_document = Document.find_by(id: document_id)
        return unless definition_document&.generated?
        return if definition_document.storage_uri.present?

        if definition_document.packet_placements.none?
          definition_document.clear_working_copy!
          return
        end

        definition_document.mark_working_refresh_started!

        manifest = PacketManifest.new(definition_document: definition_document).call
        refresh_stale_sources(manifest.stale_sources)

        refreshed_manifest = PacketManifest.new(definition_document: definition_document.reload).call

        if !definition_document.working_available? ||
           definition_document.working_manifest_hash != refreshed_manifest.manifest_hash
          WorkingCopyBuilder.new(definition_document: definition_document).call
          definition_document.reload
        end

        definition_document.mark_working_fresh!
      rescue StandardError => e
        Rails.logger.error("[RefreshWorkingCopyJob] packet=#{document_id} #{e.class}: #{e.message}")
        definition_document&.mark_working_failed!(e.message)
        raise
      end

      private

      def refresh_stale_sources(sources)
        sources.each do |source|
          result = SegmentRenderer.new(source).call

          if result.error.present?
            source.update_columns(last_render_error: result.error) # rubocop:disable Rails/SkipsModelValidations
            raise Compiler::CompileError, "Segment #{source.display_title.inspect} failed to render: #{result.error}"
          end

          source.update_columns( # rubocop:disable Rails/SkipsModelValidations
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
