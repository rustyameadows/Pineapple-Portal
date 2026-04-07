module Documents
  module Generated
    class LegacyPacketMigrator
      def initialize(document:)
        @document = document
      end

      def call
        return document if document.packet_source_backed?
        return document if document.packet_placements.exists?

        legacy_segments = document.segments.ordered.to_a
        document.update!(packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]) if legacy_segments.empty?

        Document.transaction do
          legacy_segments.each_with_index do |segment, index|
            document.packet_placements.create!(
              source: source_for(segment),
              position: index + 1
            )
          end

          document.update!(
            packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
            working_storage_uri: nil,
            working_manifest_hash: nil,
            working_checksum_sha256: nil,
            working_page_count: nil,
            working_file_size: nil,
            working_rendered_at: nil,
            working_status: Document::WORKING_STATUSES[:missing],
            working_refresh_requested_at: nil,
            working_refresh_started_at: nil,
            working_refresh_error: nil
          )
        end

        document
      end

      private

      attr_reader :document

      def source_for(segment)
        if segment.pdf_asset?
          source_for_pdf_segment(segment)
        elsif canonical_candidate?(segment)
          source_for_canonical_segment(segment)
        else
          duplicate_as_page_source(segment)
        end
      end

      def source_for_pdf_segment(segment)
        source_document = document.event.documents.find_by(id: segment.pdf_document_id) ||
                          document.event.documents.latest.find_by(logical_id: segment.pdf_logical_id)
        raise ActiveRecord::RecordNotFound, "Missing uploaded document for segment ##{segment.id}" unless source_document

        GeneratedPacketSource.find_or_create_upload_source!(document.event, source_document, title: segment.title)
      end

      def source_for_canonical_segment(segment)
        canonical = GeneratedPacketSource.ensure_canonical!(document.event, canonical_key_for(segment))
        return canonical if canonical_compatible?(canonical, segment)

        duplicate_as_page_source(segment)
      end

      def duplicate_as_page_source(segment)
        document.event.generated_packet_sources.create!(
          source_category: GeneratedPacketSource::CATEGORIES[:page],
          kind: segment.kind,
          title: segment.title,
          source_ref: deep_dup(segment.source_ref),
          spec: deep_dup(segment.spec)
        )
      end

      def canonical_candidate?(segment)
        canonical_key_for(segment).present?
      end

      def canonical_key_for(segment)
        case segment.html_view_key
        when DocumentSegment::EVENT_OVERVIEW_VIEW_KEY
          GeneratedPacketSource::CANONICAL_KEYS[:event_overview]
        when "planning_team"
          GeneratedPacketSource::CANONICAL_KEYS[:planning_team]
        when DocumentSegment::VENDOR_CONTACTS_VIEW_KEY
          GeneratedPacketSource::CANONICAL_KEYS[:vendor_contacts]
        when DocumentSegment::RUN_OF_SHOW_VIEW_KEY
          GeneratedPacketSource::CANONICAL_KEYS[:run_of_show]
        when DocumentSegment::TIMELINE_VIEW_KEY
          case timeline_view_name_for(segment).to_s
          when "Family Timeline"
            GeneratedPacketSource::CANONICAL_KEYS[:family_timeline]
          when "Photo / Video Timeline"
            GeneratedPacketSource::CANONICAL_KEYS[:photo_video_timeline]
          when "Production Timeline"
            GeneratedPacketSource::CANONICAL_KEYS[:production_timeline]
          when "Hair & Makeup Timeline", "Hair and Makeup Timeline"
            GeneratedPacketSource::CANONICAL_KEYS[:hair_makeup_timeline]
          when "Wedding Party Reference"
            GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference]
          end
        end
      end

      def timeline_view_name_for(segment)
        view_ref = segment.html_options["view_ref"].presence
        return if view_ref.blank?

        document.event.run_of_show_calendar&.event_calendar_views&.find_by(id: view_ref)&.name
      end

      def canonical_compatible?(canonical, segment)
        if canonical.canonical_key == GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference] &&
           canonical_key_for(segment) == GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference]
          return true
        end

        canonical.kind == segment.kind &&
          canonical.title == segment.title &&
          canonical.source_ref == segment.source_ref &&
          canonical.spec == segment.spec
      end

      def deep_dup(value)
        value.is_a?(Hash) ? value.deep_dup : value
      end
    end
  end
end
