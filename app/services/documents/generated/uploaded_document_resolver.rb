module Documents
  module Generated
    class UploadedDocumentResolver
      def initialize(source)
        @source = source
      end

      def call
        return unless source.pdf_asset?

        pinned_document || fallback_document
      end

      private

      attr_reader :source

      def pinned_document
        return unless source.pdf_document_id.present?

        source.event.documents.find_by(id: source.pdf_document_id)
      end

      def fallback_document
        logical_id = source.pdf_logical_id
        return unless logical_id.present?

        source.event.documents.where(logical_id: logical_id).order(version: :desc).first
      end
    end
  end
end
