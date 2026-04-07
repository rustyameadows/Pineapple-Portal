module Documents
  module Generated
    class RefreshEventPacketCachesJob < ApplicationJob
      queue_as :default

      def perform(event_id)
        event = Event.find_by(id: event_id)
        return unless event

        refresh_sources(event)
        refresh_working_packets(event)
      end

      private

      def refresh_sources(event)
        event.generated_packet_sources.find_each do |source|
          refresh_source(source)
        end
      end

      def refresh_source(source)
        return if source.group?

        result = SegmentRenderer.new(source).call

        if result.error.present?
          source.update_columns(last_render_error: result.error) # rubocop:disable Rails/SkipsModelValidations
          return
        end

        source.update_columns( # rubocop:disable Rails/SkipsModelValidations
          render_hash: result.render_hash,
          cached_pdf_key: result.storage_key,
          cached_pdf_generated_at: result.generated_at,
          cached_page_count: result.page_count,
          cached_file_size: result.file_size,
          last_render_error: nil
        )
      rescue StandardError => e
        Rails.logger.error("[RefreshEventPacketCachesJob] source=#{source.id} #{e.class}: #{e.message}")
        source.update_columns(last_render_error: e.message) # rubocop:disable Rails/SkipsModelValidations
      end

      def refresh_working_packets(event)
        packet_definitions(event).find_each do |packet|
          next if packet.packet_placements.none?

          WorkingCopyBuilder.new(definition_document: packet).call
        rescue Compiler::CompileError => e
          Rails.logger.warn("[RefreshEventPacketCachesJob] packet=#{packet.logical_id} compile error: #{e.message}")
        rescue StandardError => e
          Rails.logger.error("[RefreshEventPacketCachesJob] packet=#{packet.logical_id} #{e.class}: #{e.message}")
        end
      end

      def packet_definitions(event)
        event.documents.generated.packet_containers.where(is_template: false, storage_uri: nil)
      end
    end
  end
end
