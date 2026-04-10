module Documents
  module Generated
    class WorkingCopyRefresh
      class << self
        def enqueue(definition_document, manifest: nil)
          new(definition_document, manifest: manifest).enqueue
        end
      end

      def initialize(definition_document, manifest: nil)
        @definition_document = definition_document
        @manifest = manifest
      end

      def enqueue
        return false unless definition_document&.persisted?
        return false unless definition_document.packet_source_backed?
        return false unless definition_document.packet_container?
        return false if definition_document.packet_placements.none?

        active_build = definition_document.working_builds.in_progress.recent_first.first
        return active_build if active_build.present?

        build = definition_document.builds.create!(
          status: DocumentBuild::STATUSES[:pending],
          build_kind: DocumentBuild::BUILD_KINDS[:working],
          built_by_user: definition_document.built_by_user,
          page_numbers: true,
          manifest_hash: manifest&.manifest_hash
        )
        build.report_progress!(stage: :queued)
        definition_document.request_working_refresh!

        RunDocumentBuildJob.perform_later(build.id)
        build
      end

      private

      attr_reader :definition_document, :manifest
    end
  end
end
