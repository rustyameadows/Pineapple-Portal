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
          built_by_user: @user
        )

        @segment = DocumentSegment.create!(
          document_logical_id: @document.logical_id,
          position: 1,
          kind: DocumentSegment::KINDS[:html_view],
          title: "Text Page",
          source_ref: {
            "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
            "options" => { "body_markdown" => "Initial content" }
          },
          spec: {
            "label" => "Text Page",
            "kind" => DocumentSegment::KINDS[:html_view],
            "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY
          }
        )
      end

      test "creates text page segment with normalized markdown option" do
        assert_difference("DocumentSegment.count", 1) do
          post event_documents_generated_segments_url(@event, @document.logical_id), params: {
            segment: {
              kind: DocumentSegment::KINDS[:html_view],
              view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
              title: "General Notes",
              options: {
                body_markdown: "Line 1\r\nLine 2",
                ignored_key: "ignore me"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        created = DocumentSegment.order(:id).last

        assert_equal DocumentSegment::TEXT_PAGE_VIEW_KEY, created.html_view_key
        assert_equal({ "body_markdown" => "Line 1\nLine 2" }, created.html_options)
      end

      test "updates text page segment and drops unknown option keys" do
        patch event_documents_generated_segment_url(@event, @document.logical_id, @segment), params: {
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
        @segment.reload

        assert_equal "General Notes Updated", @segment.title
        assert_equal({ "body_markdown" => "Updated\nnotes" }, @segment.html_options)
      end

      test "creates event overview segment with default markdown when body is blank" do
        assert_difference("DocumentSegment.count", 1) do
          post event_documents_generated_segments_url(@event, @document.logical_id), params: {
            segment: {
              kind: DocumentSegment::KINDS[:html_view],
              view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
              title: "Event Overview",
              options: {
                body_markdown: "",
                ignored_key: "ignore me"
              }
            }
          }
        end

        assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
        created = DocumentSegment.order(:id).last

        assert_equal DocumentSegment::EVENT_OVERVIEW_VIEW_KEY, created.html_view_key
        assert_equal(
          { "body_markdown" => DocumentSegment.default_body_markdown_for(DocumentSegment::EVENT_OVERVIEW_VIEW_KEY) },
          created.html_options
        )
      end

      test "updates event overview segment and drops unknown option keys" do
        overview_segment = DocumentSegment.create!(
          document_logical_id: @document.logical_id,
          position: 2,
          kind: DocumentSegment::KINDS[:html_view],
          title: "Event Overview",
          source_ref: {
            "view_key" => DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
            "options" => { "body_markdown" => "Initial overview content" }
          },
          spec: {
            "label" => "Event Overview",
            "kind" => DocumentSegment::KINDS[:html_view],
            "view_key" => DocumentSegment::EVENT_OVERVIEW_VIEW_KEY
          }
        )

        patch event_documents_generated_segment_url(@event, @document.logical_id, overview_segment), params: {
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
        overview_segment.reload

        assert_equal "Event Overview Updated", overview_segment.title
        assert_equal({ "body_markdown" => "Updated\nnotes" }, overview_segment.html_options)
      end
    end
  end
end
