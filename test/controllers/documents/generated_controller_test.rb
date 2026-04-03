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
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
      )
    end

    test "show renders markdown overlay editor controls for text page packet pages" do
      create_page_placement(
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

    test "show renders markdown overlay controls for text and event overview packet pages" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text One",
        position: 1,
        options: { "body_markdown" => "One" }
      )
      create_page_placement(
        view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
        title: "Overview",
        position: 2,
        options: { "body_markdown" => "Overview content" }
      )
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Two",
        position: 3,
        options: { "body_markdown" => "Two" }
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "[data-controller='generated-markdown-editor']", count: 3
      assert_select "[data-generated-markdown-editor-target='openButton']", count: 3
      assert_select "textarea[name='segment[options][body_markdown]'][data-generated-markdown-editor-target='source']", count: 3
      assert_select "textarea.generated-builder__overlay-textarea[data-generated-markdown-editor-target='overlay'][name]", count: 0
    end

    test "index renders packet actions without portal visibility checkbox" do
      get event_documents_generated_index_url(@event)

      assert_response :success
      assert_select "input[type='checkbox'][name='document[packets_portal_visible]']", count: 0
      assert_select "a", text: "New generated packet", count: 1
      assert_select "a", text: "Packet library", count: 1
      assert_select "form button", text: "Add default packets", count: 1
      assert_select "[data-controller='document-browser']", count: 1
    end

    test "new renders create form and template list" do
      @event.documents.create!(
        title: "Cover Sheet Template",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: false,
        source: "packet",
        built_by_user: @user,
        is_template: true
      )

      get new_event_documents_generated_url(@event)

      assert_response :success
      assert_select "h1", text: "Create a packet"
      assert_select "form.generated-doc__form", count: 1
      assert_select "h2", text: "Templates"
      assert_select "li", text: "Cover Sheet Template"
    end

    test "failed create re-renders new with templates" do
      @event.documents.create!(
        title: "Timeline Template",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: false,
        source: "packet",
        built_by_user: @user,
        is_template: true
      )

      post event_documents_generated_index_url(@event), params: {
        document: {
          title: ""
        }
      }

      assert_response :unprocessable_content
      assert_select "h1", text: "Create a packet"
      assert_select "form.generated-doc__form", count: 1
      assert_select ".form-errors", count: 1
      assert_select "li", text: "Timeline Template"
    end

    test "library renders canonical reusable and uploaded asset sections" do
      create_page_source(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Shared Notes",
        options: { "body_markdown" => "Shared body" }
      )
      create_uploaded_pdf(title: "Ceremony Inserts")

      get library_event_documents_generated_index_url(@event)

      assert_response :success
      assert_select "h1", text: "Packet Library"
      assert_select "h2", text: "Canonical segments"
      assert_select "h2", text: "Reusable pages"
      assert_select "h2", text: "Uploaded packet assets"
      assert_select "td", text: "Event Overview", minimum: 1
      assert_select "td", text: "Shared Notes", count: 1
      assert_select "td", text: "Ceremony Inserts", count: 1
      assert_select "input[type='submit'][value='Insert into Generated Packet']", minimum: 1
    end

    test "add default packets uses the builder and redirects with summary" do
      created_packet = @event.documents.build(
        title: "Family Packet",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        source: "packet",
        is_latest: false,
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
      )
      service = Struct.new(:packets) do
        def call
          packets
        end
      end.new([created_packet])

      Documents::Generated::DefaultPacketBuilder.stub(:new, ->(**) { service }) do
        post add_default_packets_event_documents_generated_index_url(@event)
      end

      assert_redirected_to event_documents_generated_index_url(@event)
      follow_redirect!
      assert_includes response.body, "Added 1 default packet."
    end

    test "working pdf renders placeholder when the packet has no pages" do
      get working_pdf_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_includes response.body, "No packet pages yet. Add a canonical, page, or upload to start the live PDF."
    end

    test "snapshot requires at least one page" do
      post snapshot_event_documents_generated_url(@event, @document.logical_id)

      assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
      follow_redirect!
      assert_includes response.body, "Add at least one page before creating a snapshot."
    end

    test "show renders per-version portal actions for compiled snapshots" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      first_build = @document.builds.create!(
        status: DocumentBuild::STATUSES[:succeeded],
        build_id: SecureRandom.uuid
      )
      second_build = @document.builds.create!(
        status: DocumentBuild::STATUSES[:succeeded],
        build_id: SecureRandom.uuid
      )

      @event.documents.create!(
        title: @document.title,
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: @document.logical_id,
        version: 2,
        is_latest: true,
        source: "packet",
        storage_uri: "documents/generated-hidden-v2.pdf",
        checksum: "generated-hidden-checksum-v2",
        checksum_sha256: "generated-hidden-sha256-v2",
        size_bytes: 1024,
        content_type: "application/pdf",
        build_id: first_build.build_id,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
        packets_portal_visible: false
      )

      @event.documents.create!(
        title: @document.title,
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: @document.logical_id,
        version: 3,
        is_latest: true,
        source: "packet",
        storage_uri: "documents/generated-visible-v3.pdf",
        checksum: "generated-visible-checksum-v3",
        checksum_sha256: "generated-visible-sha256-v3",
        size_bytes: 2048,
        content_type: "application/pdf",
        build_id: second_build.build_id,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
        packets_portal_visible: true
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "input[type='checkbox'][name='document[packets_portal_visible]']", count: 0
      assert_select "button", text: "Show on portal", count: 1
      assert_select "button", text: "Hide from portal", count: 1
    end

    test "show renders uncompiled packet definitions in the sidebar navigation" do
      @event.documents.create!(
        title: "Family Packet",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: false,
        source: "packet",
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
      )

      pineapple_logical_id = SecureRandom.uuid
      @event.documents.create!(
        title: "Pineapple Productions Packet",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: pineapple_logical_id,
        version: 1,
        is_latest: false,
        source: "packet",
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
      )
      @event.documents.create!(
        title: "Pineapple Productions Packet",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: pineapple_logical_id,
        version: 2,
        is_latest: true,
        source: "packet",
        storage_uri: "documents/pineapple-productions-packet-v2.pdf",
        checksum: "pineapple-productions-packet-checksum-v2",
        checksum_sha256: "pineapple-productions-packet-sha256-v2",
        size_bytes: 2048,
        content_type: "application/pdf",
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select ".event-sidebar__subnav-link", text: "Family Packet", count: 1
      assert_select ".event-sidebar__subnav-link", text: "Pineapple Productions Packet", count: 1
    end

    private

    def create_page_placement(view_key:, title:, position:, options: {})
      source = create_page_source(view_key: view_key, title: title, options: options)
      GeneratedPacketPlacement.create!(
        document_logical_id: @document.logical_id,
        source: source,
        position: position
      )
    end

    def create_page_source(view_key:, title:, options: {})
      GeneratedPacketSource.build_page_source(
        event: @event,
        view_key: view_key,
        title: title,
        options: options
      ).tap(&:save!)
    end

    def create_uploaded_pdf(title:)
      @event.documents.create!(
        title: title,
        doc_kind: Document::DOC_KINDS[:uploaded],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: true,
        source: "staff_upload",
        storage_uri: "documents/#{title.parameterize}.pdf",
        checksum: "#{title.parameterize}-checksum",
        checksum_sha256: SecureRandom.hex(32),
        size_bytes: 1024,
        content_type: "application/pdf",
        built_by_user: @user
      )
    end
  end
end
