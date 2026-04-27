module Documents
  module Generated
    class UploadedDocumentResolver
      def initialize(source)
        @source = source
      end

      def call
        return unless source.pdf_asset?

        latest_document || original_document
      end

      private

      attr_reader :source

      def latest_document
        logical_id = source.pdf_logical_id
        return unless logical_id.present?

        event_documents
          .where(doc_kind: Document::DOC_KINDS[:uploaded], logical_id: logical_id)
          .order(version: :desc, id: :desc)
          .first
      end

      def original_document
        return unless source.pdf_document_id.present?

        event_documents
          .where(doc_kind: Document::DOC_KINDS[:uploaded])
          .find_by(id: source.pdf_document_id)
      end

      def event_documents
        event = if source.respond_to?(:event)
                  source.event
                else
                  source.document&.event
                end

        event&.documents || Document.none
      end
    end
  end
end
