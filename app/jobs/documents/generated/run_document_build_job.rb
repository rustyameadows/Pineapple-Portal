module Documents
  module Generated
    class RunDocumentBuildJob < ApplicationJob
      queue_as :default

      def perform(build_id)
        build = DocumentBuild.find(build_id)
        return if build.destroyed? || build.cancelled? || build.succeeded?

        mirror_legacy_working_refresh_started(build) if build.working?
        build.mark_running!
        result = BuildRunner.new(build: build).call
        build.mark_succeeded!(result)
      rescue ActiveRecord::RecordNotFound
        # Build was removed before the job ran; nothing to do.
      rescue BuildRunner::CancelledError
        build&.mark_cancelled!
      rescue StandardError => e
        build&.mark_failed!(e)
        mirror_legacy_working_failure(build, e) if build&.working?
        raise
      end

      private

      def mirror_legacy_working_refresh_started(build)
        build.document&.mark_working_refresh_started!
      rescue StandardError
        nil
      end

      def mirror_legacy_working_failure(build, error)
        build.document&.mark_working_failed!(error.message)
      rescue StandardError
        nil
      end
    end
  end
end
