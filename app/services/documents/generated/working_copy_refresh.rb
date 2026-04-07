module Documents
  module Generated
    class WorkingCopyRefresh
      class << self
        def enqueue(definition_document)
          new(definition_document).enqueue
        end
      end

      def initialize(definition_document)
        @definition_document = definition_document
      end

      def enqueue
        return false unless definition_document&.persisted?
        return false unless definition_document.packet_source_backed?
        return false unless definition_document.packet_container?
        return false if definition_document.packet_placements.none?
        return false unless definition_document.request_working_refresh!

        RefreshWorkingCopyJob.perform_later(definition_document.id)
        true
      end

      private

      attr_reader :definition_document
    end
  end
end
