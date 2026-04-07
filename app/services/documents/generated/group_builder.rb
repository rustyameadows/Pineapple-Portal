module Documents
  module Generated
    class GroupBuilder
      Result = Struct.new(:document, :source, keyword_init: true)

      def initialize(event:, title:, built_by_user: nil)
        @event = event
        @title = title.to_s.strip
        @built_by_user = built_by_user
      end

      def call
        raise ActiveRecord::RecordInvalid, invalid_document("Title can't be blank") if title.blank?

        document = nil
        source = nil

        Document.transaction do
          document = build_group_document
          seed_placeholder_page!(document)
          source = GeneratedPacketSource.find_or_create_group_source!(event, document)
        end

        Result.new(document: document, source: source)
      end

      private

      attr_reader :event, :title, :built_by_user

      def build_group_document
        event.documents.create!(
          title: title,
          doc_kind: Document::DOC_KINDS[:generated],
          client_visible: false,
          is_template: false,
          is_latest: false,
          built_by_user: built_by_user,
          source: "packet",
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
          packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
        )
      end

      def seed_placeholder_page!(document)
        source = GeneratedPacketSource.build_page_source(
          event: event,
          view_key: "section_break",
          title: title,
          options: {}
        )
        source.save!

        document.packet_placements.create!(source: source, position: 1)
      end

      def invalid_document(message)
        event.documents.new.tap do |document|
          document.errors.add(:title, message)
        end
      end
    end
  end
end
