module Documents
  module Generated
    class WorkingCopyRefresh
      class << self
        def enqueue(definition_document, manifest: nil, retrying: false)
          new(definition_document, manifest: manifest, retrying: retrying).enqueue
        end
      end

      def initialize(definition_document, manifest: nil, retrying: false)
        @definition_document = definition_document
        @manifest = manifest
        @retrying = retrying
      end

      def enqueue
        return false unless definition_document&.persisted?
        return false unless definition_document.packet_source_backed?
        return false unless definition_document.packet_container?
        return false if definition_document.packet_placements.none?

        created_build = false
        retrying_build = retrying
        build = definition_document.with_lock do
          definition_document.reload

          active_build = definition_document.working_builds.in_progress.recent_first.first
          if active_build&.stale?(timeout: Document::WORKING_REFRESH_TIMEOUT)
            active_build.mark_failed!(active_build.stale_error_message(timeout: Document::WORKING_REFRESH_TIMEOUT))
            retrying_build = true
          end

          active_build = definition_document.active_working_build

          next active_build if active_build.present?

          definition_document.update_columns( # rubocop:disable Rails/SkipsModelValidations
            working_status: Document::WORKING_STATUSES[:refreshing],
            working_refresh_requested_at: Time.current,
            working_refresh_started_at: nil,
            working_refresh_error: nil
          )

          created_build = true
          definition_document.builds.create!(
            status: DocumentBuild::STATUSES[:pending],
            build_kind: DocumentBuild::BUILD_KINDS[:working],
            built_by_user: definition_document.built_by_user,
            page_numbers: true,
            manifest_hash: manifest&.manifest_hash
          )
        end

        return build unless created_build

        queue_message = retrying_build ? "Retrying live PDF after a stalled render" : nil
        build.report_progress!(stage: :queued, message: queue_message)
        RunDocumentBuildJob.perform_later(build.id)
        build
      end

      private

      attr_reader :definition_document, :manifest, :retrying
    end
  end
end
