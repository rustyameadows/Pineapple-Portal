module Documents
  module Generated
    class WorkingCopyAccess
      Result = Struct.new(
        :status,
        :empty,
        :working_storage_uri,
        :rendered_at,
        :refresh_error,
        :viewer_token,
        :manifest_hash,
        keyword_init: true
      ) do
        def empty?
          !!empty
        end

        def working_available
          working_storage_uri.present?
        end

        def refreshing?
          status == Document::WORKING_STATUSES[:refreshing]
        end

        def fresh?
          status == Document::WORKING_STATUSES[:fresh]
        end

        def failed?
          status == Document::WORKING_STATUSES[:failed]
        end

        def missing?
          status == Document::WORKING_STATUSES[:missing]
        end
      end

      def initialize(definition_document:)
        @definition_document = definition_document
      end

      def call(enqueue: true)
        definition_document.reload

        if definition_document.group_container?
          return build_result(empty: definition_document.packet_placements.none?)
        end

        if definition_document.packet_placements.none?
          reset_missing_state!
          return build_result(empty: true)
        end

        manifest = PacketManifest.new(definition_document: definition_document).call

        if refresh_needed?(manifest)
          WorkingCopyRefresh.enqueue(definition_document) if enqueue
          definition_document.reload if enqueue
        elsif !definition_document.working_fresh? || definition_document.working_refresh_error.present?
          definition_document.mark_working_fresh!
          definition_document.reload
        end

        build_result(empty: false)
      end

      private

      attr_reader :definition_document

      def refresh_needed?(manifest)
        !definition_document.working_available? ||
          manifest.stale_sources.any? ||
          definition_document.working_manifest_hash != manifest.manifest_hash
      end

      def reset_missing_state!
        return if definition_document.working_missing? &&
                  !definition_document.working_available? &&
                  definition_document.working_refresh_error.blank?

        definition_document.clear_working_copy!
        definition_document.reload
      end

      def build_result(empty:)
        Result.new(
          status: definition_document.working_status_key,
          empty: empty,
          working_storage_uri: definition_document.working_storage_uri,
          rendered_at: definition_document.working_rendered_at,
          refresh_error: definition_document.working_refresh_error,
          viewer_token: definition_document.working_viewer_token,
          manifest_hash: definition_document.working_manifest_hash
        )
      end
    end
  end
end
