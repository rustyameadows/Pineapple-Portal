require "test_helper"

module Documents
  class GeneratedControllerTest < ActionDispatch::IntegrationTest
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
    end

    test "show renders markdown overlay editor controls for text page segments" do
      create_html_segment(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "[data-controller='generated-markdown-editor']", count: 1
      assert_select "[data-generated-markdown-editor-target='openButton']", count: 1
      assert_select "dialog.generated-builder__overlay-dialog[data-generated-markdown-editor-target='dialog']", count: 1
      assert_select "textarea[name='segment[options][body_markdown]'][data-generated-markdown-editor-target='source']", count: 1
      assert_select "textarea.generated-builder__overlay-textarea[data-generated-markdown-editor-target='overlay'][name]", count: 0
    end

    test "show only renders markdown overlay controls for text page segments" do
      create_html_segment(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text One",
        position: 1,
        options: { "body_markdown" => "One" }
      )
      create_html_segment(
        view_key: "event_overview",
        title: "Overview",
        position: 2
      )
      create_html_segment(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Two",
        position: 3,
        options: { "body_markdown" => "Two" }
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "[data-controller='generated-markdown-editor']", count: 2
      assert_select "[data-generated-markdown-editor-target='openButton']", count: 2
      assert_select "textarea[name='segment[options][body_markdown]'][data-generated-markdown-editor-target='source']", count: 2
      assert_select "textarea.generated-builder__overlay-textarea[data-generated-markdown-editor-target='overlay'][name]", count: 0
    end

    private

    def create_html_segment(view_key:, title:, position:, options: {})
      config = DocumentSegment.html_view(view_key)

      DocumentSegment.create!(
        document_logical_id: @document.logical_id,
        position: position,
        kind: DocumentSegment::KINDS[:html_view],
        title: title,
        source_ref: {
          "view_key" => view_key,
          "options" => options
        },
        spec: {
          "label" => config[:label],
          "kind" => DocumentSegment::KINDS[:html_view],
          "view_key" => view_key
        }
      )
    end
  end
end
