module Documents
  module Generated
    class RefreshWorkingCopyJob < ApplicationJob
      queue_as :default

      def perform(document_id)
        definition_document = Document.find_by(id: document_id)
        return unless definition_document&.generated?
        return if definition_document.storage_uri.present?
        return unless definition_document.packet_container?

        if definition_document.packet_placements.none?
          definition_document.clear_working_copy!
          return
        end

        WorkingCopyBuilder.new(definition_document: definition_document).call
      rescue StandardError => e
        Rails.logger.error("[RefreshWorkingCopyJob] packet=#{document_id} #{e.class}: #{e.message}")
        definition_document&.mark_working_failed!(e.message)
        raise
      end
    end
  end
end
