require "test_helper"

module Documents
  module Generated
    class SegmentsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @event = events(:one)
        @user = users(:one)
        log_in_as(@user)

        @document = @event.documents.create!(
          title: "Generated Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          client_visible: false,
          source: "packet",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )

        @placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
            title: "Text Page",
            options: { "body_markdown" => "Initial content" }
          ).tap(&:save!),
          position: 1
        )
      end

      test "creates text page packet page with normalized markdown option" do
        enqueued_logical_ids = []

        assert_difference("GeneratedPacketSource.count", 1) do
          assert_difference("GeneratedPacketPlacement.count", 1) do
            Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
              post event_documents_generated_segments_url(@event, @document.logical_id), params: {
                segment: {
                  view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
                  title: "General Notes",
                  options: {
                    body_markdown: "Line 1\r\nLine 2",
                    ignored_key: "ignore me"
                  }
                }
              }
            end
          end
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        created = GeneratedPacketSource.order(:id).last

        assert_equal DocumentSegment::TEXT_PAGE_VIEW_KEY, created.html_view_key
        assert_equal({ "body_markdown" => "Line 1\nLine 2" }, created.html_options)
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "create redirects back to packet settings when return_to is provided" do
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          post event_documents_generated_segments_url(@event, @document.logical_id), params: {
            return_to: return_to,
            segment: {
              view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
              title: "General Notes",
              options: {
                body_markdown: "Line 1"
              }
            }
          }
        end

        assert_redirected_to return_to
      end

      test "create failure redirects back to packet settings when return_to is provided" do
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)

        post event_documents_generated_segments_url(@event, @document.logical_id), params: {
          return_to: return_to,
          segment: {
            view_key: "",
            title: "Broken Page"
          }
        }

        assert_redirected_to return_to
      end

      test "updates text page packet page and drops unknown option keys" do
        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
          patch event_documents_generated_segment_url(@event, @document.logical_id, @placement), params: {
            segment: {
              title: "General Notes Updated",
              view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
              options: {
                body_markdown: "Updated\rnotes",
                extra: "remove me"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        @placement.reload

        assert_equal "General Notes Updated", @placement.source.title
        assert_equal({ "body_markdown" => "Updated\nnotes" }, @placement.source.html_options)
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "update redirects back to packet settings when return_to is provided" do
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          patch event_documents_generated_segment_url(@event, @document.logical_id, @placement), params: {
            return_to: return_to,
            segment: {
              title: "General Notes Updated",
              view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
              options: {
                body_markdown: "Updated notes"
              }
            }
          }
        end

        assert_redirected_to return_to
      end

      test "destroy redirects back to packet settings when return_to is provided" do
        return_to = edit_event_documents_generated_path(@event, @document.logical_id)

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          delete event_documents_generated_segment_url(@event, @document.logical_id, @placement), params: {
            return_to: return_to
          }
        end

        assert_redirected_to return_to
      end

      test "updates event overview packet page without persisting markdown options" do
        overview_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
            title: "Event Overview",
            options: {}
          ).tap(&:save!),
          position: 2
        )

        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
          patch event_documents_generated_segment_url(@event, @document.logical_id, overview_placement), params: {
            segment: {
              title: "Event Overview Updated",
              view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
              options: {
                body_markdown: "ignore this",
                extra: "ignore this too"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        overview_placement.reload

        assert_equal "Event Overview Updated", overview_placement.source.title
        assert_equal({}, overview_placement.source.html_options)
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "updates wedding party reference packet page with sanitized timeline options" do
        reference_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
            title: "Wedding Party Reference",
            options: {}
          ).tap(&:save!),
          position: 3
        )

        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
          patch event_documents_generated_segment_url(@event, @document.logical_id, reference_placement), params: {
            segment: {
              title: "Wedding Party Reference Updated",
              view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
              options: {
                timeline_mode: "manual",
                timeline_tag_ids: [
                  event_calendar_tags(:vendor).id,
                  event_calendar_tags(:wedding_party_side_a).id,
                  "",
                  999_999
                ],
                extra: "ignore this too"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        reference_placement.reload

        assert_equal "Wedding Party Reference Updated", reference_placement.source.title
        assert_equal(
          {
            "timeline_mode" => "manual",
            "timeline_tag_ids" => [
              event_calendar_tags(:vendor).id,
              event_calendar_tags(:wedding_party_side_a).id
            ]
          },
          reference_placement.source.html_options
        )
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "wedding party reference manual mode falls back to auto when no valid tags remain" do
        reference_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
            title: "Wedding Party Reference",
            options: {}
          ).tap(&:save!),
          position: 3
        )

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          patch event_documents_generated_segment_url(@event, @document.logical_id, reference_placement), params: {
            segment: {
              title: "Wedding Party Reference Updated",
              view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
              options: {
                timeline_mode: "manual",
                timeline_tag_ids: [999_999]
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        reference_placement.reload

        assert_equal(
          {
            "timeline_mode" => "auto",
            "timeline_tag_ids" => []
          },
          reference_placement.source.html_options
        )
      end

      test "updates vendor contacts packet page without persisting markdown options" do
        vendor_contacts_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
            title: "Vendor Contacts",
            options: {}
          ).tap(&:save!),
          position: 4
        )

        enqueued_logical_ids = []

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
          patch event_documents_generated_segment_url(@event, @document.logical_id, vendor_contacts_placement), params: {
            segment: {
              title: "Vendor Contacts Updated",
              view_key: DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
              options: {
                body_markdown: "ignore this",
                extra: "ignore this too"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        vendor_contacts_placement.reload

        assert_equal "Vendor Contacts Updated", vendor_contacts_placement.source.title
        assert_equal({}, vendor_contacts_placement.source.html_options)
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "creates a shared group and inserts it into the packet" do
        enqueued_logical_ids = []

        assert_difference("Document.generated.group_containers.count", 1) do
          assert_difference("GeneratedPacketSource.group_sources.count", 1) do
            assert_difference("GeneratedPacketPlacement.count", 2) do
              Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(document) { enqueued_logical_ids << document.logical_id; true } do
                post event_documents_generated_segments_url(@event, @document.logical_id), params: {
                  segment: {
                    group_title: "Design & Decor"
                  }
                }
              end
            end
          end
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        placement = GeneratedPacketPlacement.order(:id).last

        assert placement.source.group?
        assert_equal "Design & Decor", placement.source.group_document.title
        assert_equal [@document.logical_id], enqueued_logical_ids
      end

      test "updating a group title syncs the shared group document" do
        group_document = @event.documents.create!(
          title: "Design & Decor",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: SecureRandom.uuid,
          version: 1,
          is_latest: false,
          source: "packet",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
          packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
        )
        group_document.packet_placements.create!(
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: "section_break",
            title: "Design & Decor",
            options: {}
          ).tap(&:save!),
          position: 1
        )
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        group_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: group_source,
          position: 2
        )

        Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
          patch event_documents_generated_segment_url(@event, @document.logical_id, group_placement), params: {
            segment: {
              title: "Decor Vision"
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        assert_equal "Decor Vision", group_document.reload.title
        assert_equal "Decor Vision", group_source.reload.display_title
      end

      test "previewing a group keeps the generated pdf unnumbered" do
        group_document = create_group_document(title: "Design & Decor")
        group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
        group_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: group_source,
          position: 2
        )

        seen_kwargs = nil
        bundle_result = Struct.new(:pdf_data).new("PDF_BYTES")
        bundle_double = Struct.new(:result) do
          def call
            result
          end
        end.new(bundle_result)

        Documents::Generated::PacketBundle.stub :new, ->(**kwargs) {
          seen_kwargs = kwargs
          bundle_double
        } do
          get preview_event_documents_generated_segment_url(@event, @document.logical_id, group_placement)
        end

        assert_response :success
        assert_equal group_document, seen_kwargs[:definition_document]
        assert_equal false, seen_kwargs[:page_numbers]
      end

    private

    def create_group_document(title:)
      document = @event.documents.create!(
        title: title,
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: false,
        source: "packet",
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
        packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
      )

      document.packet_placements.create!(
        source: GeneratedPacketSource.build_page_source(
          event: @event,
          view_key: "section_break",
          title: title,
          options: {}
        ).tap(&:save!),
        position: 1
      )
      document
    end
  end
end
end
