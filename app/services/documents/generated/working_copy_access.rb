module Documents
  module Generated
    class WorkingCopyAccess
      FAILED_BUILD_RETRY_COOLDOWN = 30.seconds
      AUTOMATIC_RETRY_LIMIT = 1

      Result = Struct.new(
        :build,
        :build_id,
        :status,
        :empty,
        :working_storage_uri,
        :rendered_at,
        :refresh_error,
        :viewer_token,
        :manifest_hash,
        :progress_stage,
        :progress_message,
        :progress_current,
        :progress_total,
        :last_progress_at,
        keyword_init: true
      ) do
        def empty?
          !!empty
        end

        def working_available
          working_storage_uri.present?
        end

        def active?
          pending? || running?
        end

        def pending?
          status == DocumentBuild::STATUSES[:pending]
        end

        def running?
          status == DocumentBuild::STATUSES[:running]
        end

        def succeeded?
          status == DocumentBuild::STATUSES[:succeeded]
        end

        def refreshing?
          active?
        end

        def fresh?
          succeeded?
        end

        def failed?
          status == DocumentBuild::STATUSES[:failed]
        end

        def missing?
          status == "missing"
        end

        def status_payload(viewer_path:)
          BuildStatusPresenter.new(
            build: build,
            status: status,
            working_available: working_available,
            rendered_at: rendered_at,
            refresh_error: refresh_error,
            viewer_token: viewer_token,
            viewer_path: viewer_path
          ).as_json
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
        stale_build_recovered = recover_stale_build!

        if refresh_needed?(manifest, stale_build_recovered:)
          WorkingCopyRefresh.enqueue(definition_document, manifest: manifest, retrying: stale_build_recovered) if enqueue
          definition_document.reload if enqueue
        end

        build_result(empty: false)
      end

      private

      attr_reader :definition_document

      def refresh_needed?(manifest, stale_build_recovered:)
        return false if definition_document.active_working_build.present?

        latest_build = definition_document.latest_working_build
        if latest_build&.failed? && failed_build_matches_manifest?(latest_build, manifest.manifest_hash)
          return false unless automatic_retry_allowed?(manifest.manifest_hash)
          return true if stale_build_recovered

          return failed_build_retry_due?(latest_build)
        end

        !definition_document.working_available? ||
          manifest.stale_sources.any? ||
          definition_document.working_manifest_hash != manifest.manifest_hash
      end

      def recover_stale_build!
        stale_build = definition_document.recover_stale_working_build!
        return false unless stale_build.present?

        definition_document.reload
        true
      end

      def failed_build_retry_due?(build)
        retry_reference_time = build.finished_at || build.updated_at || build.created_at
        return true if retry_reference_time.blank?

        retry_reference_time <= FAILED_BUILD_RETRY_COOLDOWN.ago
      end

      def failed_build_matches_manifest?(build, manifest_hash)
        build.manifest_hash.blank? || build.manifest_hash == manifest_hash
      end

      def automatic_retry_allowed?(manifest_hash)
        consecutive_failures = definition_document.working_builds.recent_first.limit(AUTOMATIC_RETRY_LIMIT + 1).take_while do |build|
          build.failed? && failed_build_matches_manifest?(build, manifest_hash)
        end

        consecutive_failures.length <= AUTOMATIC_RETRY_LIMIT
      end

      def reset_missing_state!
        return if definition_document.working_status_key == Document::WORKING_STATUSES[:missing] &&
                  !definition_document.working_available? &&
                  definition_document.working_refresh_error.blank?

        definition_document.clear_working_copy!
        definition_document.reload
      end

      def build_result(empty:)
        progress_build = definition_document.current_working_progress_build
        current_build = progress_build || definition_document.current_working_artifact_build
        status =
          if progress_build.present?
            progress_build.status
          elsif definition_document.working_available?
            DocumentBuild::STATUSES[:succeeded]
          elsif definition_document.working_refresh_error.present?
            DocumentBuild::STATUSES[:failed]
          else
            "missing"
          end

        Result.new(
          build: current_build,
          build_id: current_build&.build_id,
          status: status,
          empty: empty,
          working_storage_uri: definition_document.working_storage_uri,
          rendered_at: definition_document.working_rendered_at,
          refresh_error: definition_document.working_refresh_error,
          viewer_token: definition_document.working_viewer_token,
          manifest_hash: definition_document.working_manifest_hash,
          progress_stage: progress_build&.progress_stage,
          progress_message: progress_build&.display_progress_message,
          progress_current: progress_build&.progress_current,
          progress_total: progress_build&.progress_total,
          last_progress_at: progress_build&.last_progress_at
        )
      end
    end
  end
end
