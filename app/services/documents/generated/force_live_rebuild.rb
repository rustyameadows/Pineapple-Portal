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
          preserved_working_copy = preserved_working_copy_attributes
          definition_document.builds.working_kind.delete_all if definition_document.persisted?

          definition_document.update_columns( # rubocop:disable Rails/SkipsModelValidations
            preserved_working_copy.merge(
              working_status: preserved_working_copy[:working_storage_uri].present? ? Document::WORKING_STATUSES[:fresh] : Document::WORKING_STATUSES[:missing],
              working_refresh_requested_at: nil,
              working_refresh_started_at: nil,
              working_refresh_error: nil
            )
          )
        end

        WorkingCopyRefresh.enqueue(definition_document)
      end

      private

      attr_reader :definition_document

      def preserved_working_copy_attributes
        {
          working_storage_uri: definition_document.working_storage_uri,
          working_manifest_hash: definition_document.working_manifest_hash,
          working_checksum_sha256: definition_document.working_checksum_sha256,
          working_page_count: definition_document.working_page_count,
          working_file_size: definition_document.working_file_size,
          working_rendered_at: definition_document.working_rendered_at
        }
      end

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
