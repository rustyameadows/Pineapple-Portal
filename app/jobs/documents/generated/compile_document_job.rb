module Documents
  module Generated
    class CompileDocumentJob < ApplicationJob
      queue_as :default

      def perform(build_id, options = {})
        build = DocumentBuild.find(build_id)
        return if build.destroyed? || build.cancelled? || build.succeeded?

        build.mark_running!
        page_numbers = !!(options && options[:page_numbers])
        result = Compiler.new(
          definition_document: build.document,
          build: build,
          built_by_user: build.built_by_user,
          page_numbers: page_numbers
        ).call
        build.mark_succeeded!(result)
      rescue ActiveRecord::RecordNotFound
        # Build was removed before the job ran; nothing to do.
      rescue Compiler::CancelledError
        build&.mark_cancelled!
      rescue StandardError => e
        build&.mark_failed!(e)
        raise
      end
    end
  end
end
