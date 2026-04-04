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

    test "show renders markdown overlay controls only for text page packet pages" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text One",
        position: 1,
        options: { "body_markdown" => "One" }
      )
      create_page_placement(
        view_key: DocumentSegment::EVENT_OVERVIEW_VIEW_KEY,
        title: "Event Overview",
        position: 2,
        options: {}
      )
      create_page_placement(
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
      assert_select ".generated-builder__hint", text: /live event, planner, and vendor data/, minimum: 1
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

    test "working status returns the current live viewer path when the working copy is fresh" do
      placement = create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )
      source = placement.source
      render_hash = "fresh-hash"
      manifest_hash = placement_manifest_hash(placement, render_hash)

      source.update!(
        render_hash: render_hash,
        cached_pdf_key: "segments/fresh.pdf",
        cached_pdf_generated_at: Time.current,
        cached_page_count: 1,
        cached_file_size: 128
      )
      @document.update!(
        working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
        working_manifest_hash: manifest_hash,
        working_checksum_sha256: "working-sha",
        working_page_count: 1,
        working_file_size: 1024,
        working_rendered_at: Time.current,
        working_status: Document::WORKING_STATUSES[:fresh]
      )

      Documents::Generated::SegmentHasher.stub :call, ->(_source) { render_hash } do
        get working_status_event_documents_generated_url(@event, @document.logical_id)
      end

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal "fresh", payload["status"]
      assert_equal true, payload["working_available"]
      assert_includes payload["viewer_path"], working_pdf_event_documents_generated_path(@event, @document.logical_id)
    end

    test "working pdf redirects to the last live copy while a refresh is pending" do
      placement = create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )
      source = placement.source

      source.update!(
        render_hash: "stale-hash",
        cached_pdf_key: "segments/stale.pdf",
        cached_pdf_generated_at: Time.current,
        cached_page_count: 1,
        cached_file_size: 128
      )
      @document.update!(
        working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
        working_manifest_hash: "older-manifest",
        working_checksum_sha256: "working-sha",
        working_page_count: 1,
        working_file_size: 1024,
        working_rendered_at: Time.current,
        working_status: Document::WORKING_STATUSES[:refreshing]
      )

      Documents::Generated::WorkingCopyRefresh.stub :enqueue, true do
        Documents::Generated::SegmentHasher.stub :call, ->(_source) { "new-hash" } do
          storage = Struct.new(:url) do
            def presigned_download_url(key:)
              url
            end
          end.new("https://example.test/live.pdf")

          R2::Storage.stub :new, storage do
            get working_pdf_event_documents_generated_url(@event, @document.logical_id)
          end
        end
      end

      assert_redirected_to "https://example.test/live.pdf#view=Fit"
    end

    test "show renders a loading shell for the live pdf frame" do
      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "[data-controller='generated-pdf-frame']", count: 1
      assert_select ".generated-builder__pdf-loading", count: 1
      assert_select "[data-generated-pdf-frame-target='message']", text: /Preparing live PDF|Refreshing live PDF/
      assert_select "iframe.generated-builder__pdf-frame[data-action='load->generated-pdf-frame#frameLoaded']", count: 1
      assert_select "[data-generated-pdf-frame-status-url-value]", count: 1
    end

    test "show renders a non blocking refresh banner while a newer live pdf is preparing" do
      placement = create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )
      source = placement.source

      source.update!(
        render_hash: "stale-hash",
        cached_pdf_key: "segments/stale.pdf",
        cached_pdf_generated_at: Time.current,
        cached_page_count: 1,
        cached_file_size: 128
      )
      @document.update!(
        working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
        working_manifest_hash: "older-manifest",
        working_checksum_sha256: "working-sha",
        working_page_count: 1,
        working_file_size: 1024,
        working_rendered_at: Time.current,
        working_status: Document::WORKING_STATUSES[:refreshing],
        working_refresh_started_at: Time.current
      )

      Documents::Generated::SegmentHasher.stub :call, ->(_source) { "new-hash" } do
        get event_documents_generated_url(@event, @document.logical_id)
      end

      assert_response :success
      assert_select ".generated-builder__pdf-status", text: /A newer live PDF is being prepared/
      assert_select ".generated-builder__pdf-status", text: /Showing the last live version until the refreshed packet is ready/
    end

    test "show renders the live update timestamp with browser local time hooks" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )
      rendered_at = Time.utc(2026, 4, 4, 0, 9)
      @document.update!(
        working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
        working_manifest_hash: "live-manifest",
        working_checksum_sha256: "working-sha",
        working_page_count: 1,
        working_file_size: 1024,
        working_rendered_at: rendered_at,
        working_status: Document::WORKING_STATUSES[:fresh]
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "time[data-controller='local-time'][data-local-time-iso-value='#{rendered_at.iso8601}'][datetime='#{rendered_at.iso8601}']", count: 1
    end

    test "show renders browser local time hooks for latest snapshot and build history timestamps" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      build = @document.builds.create!(
        status: DocumentBuild::STATUSES[:succeeded],
        build_id: SecureRandom.uuid,
        started_at: Time.utc(2026, 4, 4, 0, 10),
        finished_at: Time.utc(2026, 4, 4, 0, 12)
      )

      latest_snapshot = @event.documents.create!(
        title: @document.title,
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: @document.logical_id,
        version: 2,
        is_latest: true,
        source: "packet",
        storage_uri: "documents/generated-visible-v2.pdf",
        checksum: "generated-visible-checksum-v2",
        checksum_sha256: "generated-visible-sha256-v2",
        size_bytes: 2048,
        content_type: "application/pdf",
        build_id: build.build_id,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
        updated_at: Time.utc(2026, 4, 4, 0, 12)
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "p.event-section__meta time[data-controller='local-time'][data-local-time-iso-value='#{latest_snapshot.updated_at.iso8601}'][data-local-time-format-value='long']", count: 1
      assert_select ".generated-builder__build-meta time[data-controller='local-time'][data-local-time-format-value='short']", minimum: 2
    end

    test "edit renders packet settings and delete controls" do
      get edit_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "h1", text: "Packet Settings"
      assert_select "form", minimum: 2
      assert_select "button", text: "Delete packet", count: 1
    end

    test "destroy removes the generated packet definition" do
      logical_id = @document.logical_id

      assert_difference("Document.where(logical_id: logical_id).count", -1) do
        delete event_documents_generated_url(@event, logical_id)
      end

      assert_redirected_to event_documents_generated_index_url(@event)
      assert_nil Document.where(logical_id: logical_id).first
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

    def placement_manifest_hash(placement, render_hash)
      Digest::SHA256.hexdigest(JSON.dump([
        {
          entry_key: "placement:#{placement.id}",
          source_key: "#{placement.source.class.name}:#{placement.source.id}",
          render_hash: render_hash
        }
      ]))
    end
  end
end
