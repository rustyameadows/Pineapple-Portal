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
        assert_difference("GeneratedPacketSource.count", 1) do
          assert_difference("GeneratedPacketPlacement.count", 1) do
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

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        created = GeneratedPacketSource.order(:id).last

        assert_equal DocumentSegment::TEXT_PAGE_VIEW_KEY, created.html_view_key
        assert_equal({ "body_markdown" => "Line 1\nLine 2" }, created.html_options)
      end

      test "updates text page packet page and drops unknown option keys" do
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

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        @placement.reload

        assert_equal "General Notes Updated", @placement.source.title
        assert_equal({ "body_markdown" => "Updated\nnotes" }, @placement.source.html_options)
      end

      test "creates event overview packet page with default markdown when body is blank" do
        assert_difference("GeneratedPacketSource.count", 1) do
          assert_difference("GeneratedPacketPlacement.count", 1) do
            post event_documents_generated_segments_url(@event, @document.logical_id), params: {
              segment: {
                view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
                title: "Event Overview",
                options: {
                  body_markdown: "",
                  ignored_key: "ignore me"
                }
              }
            }
          end
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        created = GeneratedPacketSource.order(:id).last

        assert_equal DocumentSegment::EVENT_OVERVIEW_VIEW_KEY, created.html_view_key
        assert_equal(
          { "body_markdown" => DocumentSegment.default_body_markdown_for(DocumentSegment::EVENT_OVERVIEW_VIEW_KEY) },
          created.html_options
        )
      end

      test "updates event overview packet page and drops unknown option keys" do
        overview_placement = GeneratedPacketPlacement.create!(
          document_logical_id: @document.logical_id,
          source: GeneratedPacketSource.build_page_source(
            event: @event,
            view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
            title: "Event Overview",
            options: { "body_markdown" => "Initial overview content" }
          ).tap(&:save!),
          position: 2
        )

        patch event_documents_generated_segment_url(@event, @document.logical_id, overview_placement), params: {
          segment: {
            title: "Event Overview Updated",
            view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
            options: {
              body_markdown: "Updated\rnotes",
              extra: "remove me"
            }
          }
        }

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        overview_placement.reload

        assert_equal "Event Overview Updated", overview_placement.source.title
        assert_equal({ "body_markdown" => "Updated\nnotes" }, overview_placement.source.html_options)
      end
    end
  end
end
