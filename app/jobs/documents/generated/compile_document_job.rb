module Documents
  module Generated
    class CompileDocumentJob < ApplicationJob
      queue_as :default

      def perform(build_id, options = {})
        build = DocumentBuild.find(build_id)
        build.update!(page_numbers: !!options[:page_numbers]) if options.key?(:page_numbers)

        RunDocumentBuildJob.perform_now(build.id)
      rescue ActiveRecord::RecordNotFound
        # Build was removed before the job ran; nothing to do.
      end
    end
  end
end
