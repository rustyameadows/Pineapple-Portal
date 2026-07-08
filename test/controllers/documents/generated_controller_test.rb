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

    test "edit renders markdown overlay editor controls for text page packet pages" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      get edit_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "[data-controller='generated-markdown-editor']", count: 1
      assert_select "[data-generated-markdown-editor-target='openButton']", count: 1
      assert_select "dialog.generated-builder__overlay-dialog[data-generated-markdown-editor-target='dialog']", count: 1
      assert_select "dialog.generated-builder__segment-dialog", count: 1
      assert_select "textarea[name='segment[options][body_markdown]'][data-generated-markdown-editor-target='source']", count: 1
      assert_select "textarea.generated-builder__overlay-textarea[data-generated-markdown-editor-target='overlay'][name]", count: 0
    end

    test "edit renders markdown overlay controls only for text page packet pages" do
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
      create_page_placement(
        view_key: DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        title: "Wedding Party Reference",
        position: 4,
        options: {}
      )
      create_page_placement(
        view_key: DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
        title: "Vendor Contacts",
        position: 5,
        options: {}
      )

      get edit_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "[data-controller='generated-markdown-editor']", count: 2
      assert_select "[data-generated-markdown-editor-target='openButton']", count: 2
      assert_select "button", text: "Settings", count: 5
      assert_select "button", text: "Duplicate", count: 0
      assert_select "details", count: 0
      assert_select "dialog.generated-builder__segment-dialog", count: 5
      assert_select "textarea[name='segment[options][body_markdown]'][data-generated-markdown-editor-target='source']", count: 2
      assert_select "textarea.generated-builder__overlay-textarea[data-generated-markdown-editor-target='overlay'][name]", count: 0
      assert_select ".generated-builder__hint", text: /live event, planner, and vendor data/, minimum: 1
      assert_select ".generated-builder__hint", text: /live planner and vendor data/, minimum: 1
      assert_select ".generated-builder__hint", text: /Auto mode uses the first two key-person groups/, minimum: 1
      assert_select "select[name='segment[options][timeline_mode]']", count: 1
      assert_select "select[name='segment[options][timeline_tag_ids][]']", count: 4
    end

    test "edit exposes custom timeline views in the canonical segment picker" do
      get edit_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "select[name='segment[source_id]'] option", text: "Vendor Only", count: 1
      assert_select "select[name='segment[source_id]'] option", text: "Decision Calendar", count: 0
      assert_select "select[name='segment[source_id]'] option", text: "Photo / Video Timeline", count: 1
    end

    test "edit prefixes cover and section titles in the packet builder list only" do
      create_page_placement(
        view_key: "cover_sheet",
        title: "Smith Weekend",
        position: 1,
        options: {}
      )
      create_page_placement(
        view_key: "section_break",
        title: "Travel",
        position: 2,
        options: {}
      )

      get edit_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select ".generated-builder__toc-title", text: "Cover - Smith Weekend", count: 1
      assert_select ".generated-builder__toc-title", text: "Section - Travel", count: 1
      assert_select "input[name='segment[title]'][value='Smith Weekend']", count: 1
      assert_select "input[name='segment[title]'][value='Travel']", count: 1
    end

    test "edit renders group children as nested dense rows with group scoped actions" do
      group_document = create_group_document(title: "Design & Decor")
      child_placement = group_document.packet_placements.create!(
        source: create_page_source(
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Floral Proposal",
          options: { "body_markdown" => "Flowers" }
        ),
        position: 2
      )
      group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
      group_placement = @document.packet_placements.create!(source: group_source, position: 1)
      top_level_placement = @document.packet_placements.create!(
        source: create_page_source(
          view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
          title: "Standalone Notes",
          options: { "body_markdown" => "Standalone" }
        ),
        position: 2
      )

      get edit_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select ".generated-builder__toc-item--group .generated-builder__toc-title", text: "Design & Decor", count: 1
      assert_select ".generated-builder__toc-item--group .generated-builder__status-tag", text: "Group", count: 0
      assert_select ".generated-builder__toc-item--group .generated-builder__status-tag", text: "2 pages", count: 0
      assert_select ".generated-builder__toc-children .generated-builder__toc-title", text: "Section - Design & Decor", count: 1
      assert_select ".generated-builder__toc-children .generated-builder__toc-title", text: "Floral Proposal", count: 1

      assert_select "a[href='#{preview_event_documents_generated_segment_path(@event, @document.logical_id, group_placement)}']", text: "Preview", count: 1
      assert_select "form.generated-builder__segment-dialog-form[action^='#{event_documents_generated_segment_path(@event, @document.logical_id, group_placement)}']", count: 1
      assert_select "form.generated-builder__toc-action-form[action^='#{event_documents_generated_segment_path(@event, @document.logical_id, group_placement)}']", count: 1
      assert_select ".generated-builder__toc-children a[href='#{preview_event_documents_generated_segment_path(@event, group_document.logical_id, child_placement)}']", text: "Preview", count: 1
      assert_select ".generated-builder__toc-children form.generated-builder__segment-dialog-form[action^='#{event_documents_generated_segment_path(@event, group_document.logical_id, child_placement)}']", count: 1
      assert_select ".generated-builder__toc-children form.generated-builder__toc-action-form[action^='#{event_documents_generated_segment_path(@event, group_document.logical_id, child_placement)}']", count: 1
      assert_select "form.generated-builder__move-form[action^='#{move_to_group_event_documents_generated_segment_path(@event, @document.logical_id, top_level_placement)}'] select[name='target_group_placement_id'] option[value='#{group_placement.id}']", text: "Design & Decor", count: 1
      assert_select ".generated-builder__toc-children form.generated-builder__move-form[action^='#{move_out_of_group_event_documents_generated_segment_path(@event, group_document.logical_id, child_placement)}']", count: 1
      assert_select ".generated-builder__toc-children form.generated-builder__move-form input[name='packet_logical_id'][value='#{@document.logical_id}']", count: 2
      assert_select ".generated-builder__toc-children form.generated-builder__move-form input[name='group_placement_id'][value='#{group_placement.id}']", count: 2
    end

    test "edit keeps dense row metadata to render status and shared packet tooltip" do
      shared_source = create_page_source(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Shared Notes",
        options: { "body_markdown" => "Shared body" }
      )
      @document.packet_placements.create!(source: shared_source, position: 1)
      shared_packet = @event.documents.create!(
        title: "Vendor Packet",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: false,
        source: "packet",
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
      )
      shared_packet.packet_placements.create!(source: shared_source, position: 1)

      get edit_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select ".generated-builder__toc-title", text: "Shared Notes", count: 1
      assert_select ".generated-builder__toc-usage", count: 0
      assert_select ".generated-builder__toc-meta .generated-builder__status-tag", text: "Page", count: 0
      assert_select ".generated-builder__toc-meta .generated-builder__status-tag", text: "Not rendered", count: 1
      assert_select ".generated-builder__toc-meta .generated-builder__status-tag[title='Used in: Generated Packet, Vendor Packet']", text: "Shared in 2 packets", count: 1
    end

    test "show keeps packet page management off the preview screen" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "p.event-section__eyebrow", text: "Generated packet", count: 0
      assert_select "p.event-section__meta", text: /No saved snapshots yet/, count: 0
      assert_select "h2", text: "Live Working PDF", count: 1
      assert_select "h2", text: "Snapshots & downloads", count: 1
      assert_select "h2", text: "Packet Pages", count: 0
      assert_select "a", text: "Packet library", count: 0
      assert_select "a", text: "Back to documents", count: 0
      assert_select "header .generated-builder__actions a", text: "Download latest", count: 0
      assert_select "button", text: "Create snapshot", count: 1
      assert_select "button", text: "Create snapshot without page numbers", count: 1
      assert_select "button", text: "Settings", count: 0
      assert_select "[data-controller='generated-markdown-editor']", count: 0
      assert_select "dialog.generated-builder__live-rebuild-dialog", count: 1
    end

    test "show renders successfully with a planning team page source" do
      create_page_placement(
        view_key: "planning_team",
        title: "Planning Team",
        position: 1,
        options: {}
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "h2", text: "Live Working PDF", count: 1
    end

    test "index renders packet actions without portal visibility checkbox" do
      travel_to Time.zone.local(2026, 4, 8, 2, 11, 55) do
        logical_id = SecureRandom.uuid
        @event.documents.create!(
          title: "Family Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: logical_id,
          version: 1,
          is_latest: false,
          source: "packet",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
        )
        @event.documents.create!(
          title: "Family Packet",
          doc_kind: Document::DOC_KINDS[:generated],
          logical_id: logical_id,
          version: 2,
          is_latest: true,
          source: "packet",
          storage_uri: "documents/family-packet-v2.pdf",
          checksum: "family-packet-checksum-v2",
          checksum_sha256: "family-packet-sha256-v2",
          size_bytes: 2048,
          content_type: "application/pdf",
          built_by_user: @user,
          packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
          updated_at: Time.zone.local(2026, 4, 4, 0, 18)
        )

        get event_documents_generated_index_url(@event)
      end

      assert_response :success
      assert_select "p.event-section__eyebrow", text: "Generated packets", count: 0
      assert_select "div.event-section__actions.event-section__actions--row", count: 1
      assert_select "input[type='checkbox'][name='document[packets_portal_visible]']", count: 0
      assert_select "a", text: "New generated packet", count: 1
      assert_select "a", text: "Packet library", count: 1
      assert_select "form button", text: "Add default packets", count: 1
      assert_select "[data-controller='document-browser']", count: 1
      assert_select "th", text: "Saved snapshots", count: 0
      assert_select "td", text: "4 days ago", minimum: 1
      assert_select "a.documents-browser__action-link", text: "Edit packet", minimum: 1
      assert_select "a.documents-browser__action-link", text: "View packet", minimum: 1
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
      assert_select "td", text: "Photo / Video Timeline", minimum: 1
      assert_select "td", text: "Hair & Makeup Timeline", minimum: 1
      assert_select "td", text: "Vendor Only", count: 1
      assert_select "td", text: "Decision Calendar", count: 0
      assert_select "td", text: "Vendor Contacts", minimum: 1
      assert_select "td", text: "Shared Notes", count: 1
      assert_select "td", text: "Ceremony Inserts", count: 1
      assert_select "input[type='submit'][value='Insert into Generated Packet']", minimum: 1
    end

    test "library renders shared groups with manage links" do
      group_document = create_group_document(title: "Design & Decor")
      group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
      @document.packet_placements.create!(source: group_source, position: 1)

      get library_event_documents_generated_index_url(@event)

      assert_response :success
      assert_select "h2", text: "Groups"
      assert_select "td", text: "Design & Decor", minimum: 1
      assert_select "a", text: "Manage", minimum: 1
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
      result = Struct.new(:packets, :summary_message).new(
        [created_packet],
        "Added 4 default groups and 1 default packet."
      )
      service = Struct.new(:result) do
        def call
          result
        end
      end.new(result)

      Documents::Generated::DefaultPacketBuilder.stub(:new, ->(**) { service }) do
        post add_default_packets_event_documents_generated_index_url(@event)
      end

      assert_redirected_to event_documents_generated_index_url(@event)
      follow_redirect!
      assert_includes response.body, "Added 4 default groups and 1 default packet."
    end

    test "working pdf renders placeholder when the packet has no pages" do
      get working_pdf_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_includes response.headers["Cache-Control"], "no-store"
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
      working_build = @document.builds.create!(
        build_kind: DocumentBuild::BUILD_KINDS[:working],
        status: DocumentBuild::STATUSES[:succeeded],
        storage_uri: @document[:working_storage_uri],
        manifest_hash: manifest_hash,
        checksum_sha256: "working-sha",
        compiled_page_count: 1,
        file_size: 1024,
        page_numbers: true,
        finished_at: Time.current
      )

      Documents::Generated::SegmentHasher.stub :call, ->(_source) { render_hash } do
        get working_status_event_documents_generated_url(@event, @document.logical_id)
      end

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal DocumentBuild::STATUSES[:succeeded], payload["status"]
      assert_equal true, payload["working_available"]
      assert_equal "#{working_pdf_event_documents_generated_path(@event, @document.logical_id, v: working_build.viewer_token)}#view=Fit", payload["viewer_path"]
    end

    test "working status reports build-backed progress while serving the latest successful live pdf" do
      placement = create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )
      render_hash = "fresh-hash"
      manifest_hash = placement_manifest_hash(placement, render_hash)

      placement.source.update!(
        render_hash: render_hash,
        cached_pdf_key: "segments/fresh.pdf",
        cached_pdf_generated_at: Time.current,
        cached_page_count: 1,
        cached_file_size: 128
      )

      successful_build = @document.builds.create!(
        build_kind: DocumentBuild::BUILD_KINDS[:working],
        status: DocumentBuild::STATUSES[:succeeded],
        storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
        manifest_hash: manifest_hash,
        checksum_sha256: "working-sha",
        compiled_page_count: 1,
        file_size: 1024,
        page_numbers: true,
        finished_at: Time.current
      )

      @document.builds.create!(
        build_kind: DocumentBuild::BUILD_KINDS[:working],
        status: DocumentBuild::STATUSES[:running],
        manifest_hash: manifest_hash,
        page_numbers: true,
        progress_stage: DocumentBuild::PROGRESS_STAGES[:rendering_entries],
        progress_message: "Rendering pages 1/3",
        progress_current: 1,
        progress_total: 3,
        last_progress_at: Time.current,
        started_at: Time.current
      )

      Documents::Generated::SegmentHasher.stub :call, ->(_source) { render_hash } do
        get working_status_event_documents_generated_url(@event, @document.logical_id)
      end

      assert_response :success
      payload = JSON.parse(response.body)
      assert_equal DocumentBuild::STATUSES[:running], payload["status"]
      assert_equal "Rendering pages 1/3", payload["progress_message"]
      assert_equal true, payload["working_available"]
      assert_equal successful_build.viewer_token, payload["viewer_token"]
    end

    test "working pdf returns the current live pdf bytes with no-store headers when v is missing" do
      placement = create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )
      source = placement.source
      pdf_bytes = "%PDF-1.4\nlatest live pdf\n"

      source.update!(
        render_hash: "fresh-hash",
        cached_pdf_key: "segments/fresh.pdf",
        cached_pdf_generated_at: Time.current,
        cached_page_count: 1,
        cached_file_size: 128
      )
      @document.update!(
        working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
        working_manifest_hash: placement_manifest_hash(placement, "fresh-hash"),
        working_checksum_sha256: "working-sha",
        working_page_count: 1,
        working_file_size: 1024,
        working_rendered_at: Time.current,
        working_status: Document::WORKING_STATUSES[:fresh]
      )

      storage_class = Struct.new(:payload) do
        def download(key)
          StringIO.new(payload)
        end
      end
      storage = storage_class.new(pdf_bytes)

      Documents::Generated::SegmentHasher.stub :call, ->(_source) { "fresh-hash" } do
        R2::Storage.stub :new, storage do
          get working_pdf_event_documents_generated_url(@event, @document.logical_id)
        end
      end

      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal pdf_bytes, response.body
    end

    test "working pdf returns the current live pdf bytes with no-store headers when v is stale" do
      placement = create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )
      source = placement.source
      pdf_bytes = "%PDF-1.4\ncurrent live pdf\n"

      source.update!(
        render_hash: "fresh-hash",
        cached_pdf_key: "segments/fresh.pdf",
        cached_pdf_generated_at: Time.current,
        cached_page_count: 1,
        cached_file_size: 128
      )
      @document.update!(
        working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
        working_manifest_hash: placement_manifest_hash(placement, "fresh-hash"),
        working_checksum_sha256: "working-sha",
        working_page_count: 1,
        working_file_size: 1024,
        working_rendered_at: Time.current,
        working_status: Document::WORKING_STATUSES[:fresh]
      )

      storage_class = Struct.new(:payload) do
        def download(key)
          StringIO.new(payload)
        end
      end
      storage = storage_class.new(pdf_bytes)

      Documents::Generated::SegmentHasher.stub :call, ->(_source) { "fresh-hash" } do
        R2::Storage.stub :new, storage do
          get working_pdf_event_documents_generated_url(@event, @document.logical_id, v: "stale-token")
        end
      end

      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal pdf_bytes, response.body
    end

    test "working pdf returns inline bytes with no-store cache headers for the current token" do
      placement = create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )
      source = placement.source
      render_hash = "fresh-hash"
      manifest_hash = placement_manifest_hash(placement, render_hash)
      pdf_bytes = "%PDF-1.4\nstable live pdf\n"

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
        working_rendered_at: Time.utc(2026, 4, 7, 18, 0),
        working_status: Document::WORKING_STATUSES[:fresh]
      )

      storage_class = Struct.new(:payload) do
        def download(key)
          StringIO.new(payload)
        end
      end
      storage = storage_class.new(pdf_bytes)

      Documents::Generated::SegmentHasher.stub :call, ->(_source) { render_hash } do
        R2::Storage.stub :new, storage do
          get working_pdf_event_documents_generated_url(@event, @document.logical_id, v: @document.working_viewer_token)
        end
      end

      assert_response :success
      assert_equal "application/pdf", response.media_type
      assert_includes response.headers["Content-Disposition"], "inline"
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal pdf_bytes, response.body
    end

    test "show renders a loading shell for the live pdf frame" do
      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "[data-controller~='generated-pdf-frame']", count: 1
      assert_select ".generated-builder__pdf-loading", count: 1
      assert_select "[data-generated-pdf-frame-target='message']", text: /Preparing live PDF|Refreshing live PDF/
      assert_select "iframe.generated-builder__pdf-frame[data-action='load->generated-pdf-frame#frameLoaded']", count: 1
      assert_select "[data-generated-pdf-frame-status-url-value]", count: 1
    end

    test "show keeps the first-build status area free of extra rebuild buttons" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select ".generated-builder__pdf-status-actions", count: 0
      assert_select ".generated-builder__live-pill[hidden]", count: 1
      assert_select "dialog.generated-builder__live-rebuild-dialog", count: 1
      assert_select "form.generated-builder__inline-form[action='#{rebuild_live_event_documents_generated_path(@event, @document.logical_id)}']", count: 1
    end

    test "show renders build-backed live progress while a newer live pdf is preparing" do
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

      successful_build = @document.builds.create!(
        build_kind: DocumentBuild::BUILD_KINDS[:working],
        status: DocumentBuild::STATUSES[:succeeded],
        storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/generated-packet-working.pdf",
        manifest_hash: "older-manifest",
        checksum_sha256: "working-sha",
        compiled_page_count: 1,
        file_size: 1024,
        page_numbers: true,
        finished_at: Time.current
      )
      @document.builds.create!(
        build_kind: DocumentBuild::BUILD_KINDS[:working],
        status: DocumentBuild::STATUSES[:running],
        manifest_hash: "new-hash",
        page_numbers: true,
        progress_stage: DocumentBuild::PROGRESS_STAGES[:rendering_entries],
        progress_message: "Rendering pages 2/5",
        progress_current: 2,
        progress_total: 5,
        last_progress_at: Time.current,
        started_at: Time.current
      )

      Documents::Generated::SegmentHasher.stub :call, ->(_source) { "new-hash" } do
        get event_documents_generated_url(@event, @document.logical_id)
      end

      assert_response :success
      assert_equal successful_build.viewer_token, @document.reload.working_viewer_token
      assert_select ".generated-builder__pdf-status", text: /Rendering pages 2\/5/
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
      working_build = @document.builds.create!(
        build_kind: DocumentBuild::BUILD_KINDS[:working],
        status: DocumentBuild::STATUSES[:succeeded],
        storage_uri: @document[:working_storage_uri],
        manifest_hash: "live-manifest",
        checksum_sha256: "working-sha",
        compiled_page_count: 1,
        file_size: 1024,
        page_numbers: true,
        finished_at: rendered_at
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select ".generated-builder__live-pill", text: /Updated/, count: 1
      assert_select "button.generated-builder__live-pill[data-action='generated-segment-dialog#open']", text: /Updated/, count: 1
      assert_select ".generated-builder__live-pill", text: /Auto-updating/, count: 0
      expected_frame_path = "#{working_pdf_event_documents_generated_path(@event, @document.logical_id, v: working_build.viewer_token)}#view=Fit"
      expected_open_path = "#{working_pdf_event_documents_generated_path(@event, @document.logical_id)}#view=Fit"
      assert_select "a[href='#{expected_open_path}']", text: "Open live PDF", count: 1
      assert_select "iframe.generated-builder__pdf-frame[src='#{expected_frame_path}']", count: 1
      assert_select "time[data-controller='local-time'][data-local-time-iso-value='#{rendered_at.iso8601}'][datetime='#{rendered_at.iso8601}']", count: 1
      assert_select "dialog.generated-builder__live-rebuild-dialog", count: 1
      assert_select "form.generated-builder__inline-form[action='#{rebuild_live_event_documents_generated_path(@event, @document.logical_id)}']", count: 1
    end

    test "rebuild live delegates to the force rebuild service" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      force_rebuild_calls = []
      service = Struct.new(:calls) do
        def call
          calls << true
        end
      end.new([])

      Documents::Generated::ForceLiveRebuild.stub :new, ->(**kwargs) { force_rebuild_calls << kwargs; service } do
        post rebuild_live_event_documents_generated_url(@event, @document.logical_id), params: {
          return_to: event_documents_generated_path(@event, @document.logical_id)
        }
      end

      assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
      assert_equal [{ definition_document: @document }], force_rebuild_calls
      assert_equal [true], service.calls
      follow_redirect!
      assert_includes response.body, "Live PDF rebuild queued."
    end

    test "rebuild live rejects packets with empty group placements before clearing the working copy" do
      group_document = @event.documents.create!(
        title: "Empty Group",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: false,
        source: "packet",
        built_by_user: @user,
        packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
        packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
      )
      group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
      @document.packet_placements.create!(source: group_source, position: 1)
      @document.update!(
        working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/live.pdf",
        working_manifest_hash: "live-manifest",
        working_checksum_sha256: "live-sha",
        working_page_count: 2,
        working_file_size: 1024,
        working_rendered_at: Time.current,
        working_status: Document::WORKING_STATUSES[:fresh]
      )

      force_rebuild_called = false

      Documents::Generated::ForceLiveRebuild.stub :new, ->(**_kwargs) {
        force_rebuild_called = true
        raise "should not rebuild"
      } do
        post rebuild_live_event_documents_generated_url(@event, @document.logical_id), params: {
          return_to: event_documents_generated_path(@event, @document.logical_id)
        }
      end

      assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
      assert_not force_rebuild_called
      assert_equal "documents/#{@event.id}/#{@document.logical_id}/working/live.pdf", @document.reload.working_storage_uri
      follow_redirect!
      assert_includes response.body, "Empty Group: add at least one group page"
    end

    test "rebuild live rejects packets with missing stored pdf attachments before clearing the working copy" do
      uploaded_document = create_uploaded_pdf(title: "Missing Attachment")
      uploaded_document.update_columns(storage_uri: nil) # rubocop:disable Rails/SkipsModelValidations
      upload_source = GeneratedPacketSource.find_or_create_upload_source!(@event, uploaded_document)
      @document.packet_placements.create!(source: upload_source, position: 1)
      @document.update!(
        working_storage_uri: "documents/#{@event.id}/#{@document.logical_id}/working/live.pdf",
        working_manifest_hash: "live-manifest",
        working_checksum_sha256: "live-sha",
        working_page_count: 2,
        working_file_size: 1024,
        working_rendered_at: Time.current,
        working_status: Document::WORKING_STATUSES[:fresh]
      )

      force_rebuild_called = false

      Documents::Generated::ForceLiveRebuild.stub :new, ->(**_kwargs) {
        force_rebuild_called = true
        raise "should not rebuild"
      } do
        post rebuild_live_event_documents_generated_url(@event, @document.logical_id), params: {
          return_to: event_documents_generated_path(@event, @document.logical_id)
        }
      end

      assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
      assert_not force_rebuild_called
      assert_equal "documents/#{@event.id}/#{@document.logical_id}/working/live.pdf", @document.reload.working_storage_uri
      follow_redirect!
      assert_includes response.body, "Missing Attachment: attached PDF is missing a stored file"
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
      assert_select "p.event-section__meta", count: 0
      assert_select ".generated-builder__hint time[data-controller='local-time'][data-local-time-iso-value='#{latest_snapshot.updated_at.iso8601}'][data-local-time-format-value='long']", count: 1
      assert_select ".generated-builder__build-meta time[data-controller='local-time'][data-local-time-format-value='short']", minimum: 2
    end

    test "edit renders packet settings, delete controls, and packet page management" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Planner Notes",
        position: 1,
        options: { "body_markdown" => "Notes" }
      )

      get edit_event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "p.event-section__eyebrow", text: "Generated Packet", count: 1
      assert_select "h1", text: "Packet Settings"
      assert_select "h2", text: "Packet Pages", count: 1
      assert_select ".generated-builder__view-toggle", count: 0
      assert_select "button", text: "Grid", count: 0
      assert_select "button", text: "List", count: 0
      assert_select ".generated-builder__toc-head", count: 1
      assert_select ".generated-builder__toc-title", text: "Planner Notes", count: 1
      assert_select "select[name='segment[source_id]'] option", text: "Photo / Video Timeline", minimum: 1
      assert_select "select[name='segment[source_id]'] option", text: "Hair & Makeup Timeline", minimum: 1
      assert_select "input[type='submit'][value='Insert canonical']", count: 1
      assert_select "input[type='submit'][value='Reuse page']", count: 1
      assert_select "input[type='submit'][value='Create page']", count: 1
      assert_select "input[type='submit'][value='Attach PDF']", count: 1
      assert_select "input[type='submit'][value='Upload and add PDF']", count: 1
      assert_select ".generated-doc__compact-settings", count: 1
      assert_select ".generated-doc__compact-settings input[name='document[title]']", count: 1
      assert_select ".generated-doc__compact-settings input[type='checkbox'][name='document[client_visible]']", count: 0
      assert_select ".generated-doc__compact-settings input[type='submit'][value='Save']", count: 1
      assert_select "button", text: "Delete packet", count: 1
      assert_select ".generated-builder__build-details", count: 0
    end

    test "edit renders group settings and group pages for a group container" do
      group_document = create_group_document(title: "Design & Decor")

      get edit_event_documents_generated_url(@event, group_document.logical_id)

      assert_response :success
      assert_select "h1", text: "Group Settings"
      assert_select "h2", text: "Group Pages", count: 1
      assert_select ".generated-doc__compact-settings input[name='document[title]']", count: 1
      assert_select ".generated-doc__compact-settings input[type='submit'][value='Save']", count: 1
      assert_select "input[type='submit'][value='Insert group']", count: 0
      assert_select "input[type='submit'][value='Create and insert group']", count: 0
      assert_select "button", text: "Delete group", count: 1
    end

    test "show redirects group containers to edit" do
      group_document = create_group_document(title: "Design & Decor")

      get event_documents_generated_url(@event, group_document.logical_id)

      assert_redirected_to edit_event_documents_generated_url(@event, group_document.logical_id)
    end

    test "destroy removes the generated packet definition" do
      logical_id = @document.logical_id

      assert_difference("Document.where(logical_id: logical_id).count", -1) do
        delete event_documents_generated_url(@event, logical_id)
      end

      assert_redirected_to event_documents_generated_index_url(@event)
      assert_nil Document.where(logical_id: logical_id).first
    end

    test "snapshot defaults to page numbers when page_numbers is omitted" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      enqueued_options = []

      Documents::Generated::RunDocumentBuildJob.stub :perform_later, ->(build_id) { enqueued_options << DocumentBuild.find(build_id).page_numbers } do
        assert_difference("DocumentBuild.count", 1) do
          post snapshot_event_documents_generated_url(@event, @document.logical_id)
        end
      end

      assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
      assert_equal [true], enqueued_options
    end

    test "snapshot can opt out of page numbers" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      enqueued_options = []

      Documents::Generated::RunDocumentBuildJob.stub :perform_later, ->(build_id) { enqueued_options << DocumentBuild.find(build_id).page_numbers } do
        assert_difference("DocumentBuild.count", 1) do
          post snapshot_event_documents_generated_url(@event, @document.logical_id), params: { page_numbers: false }
        end
      end

      assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
      assert_equal [false], enqueued_options
    end

    test "snapshot reuses the active build instead of enqueueing a duplicate" do
      create_page_placement(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Text Notes",
        position: 1,
        options: { "body_markdown" => "## Notes" }
      )

      active_build = @document.builds.create!(
        status: DocumentBuild::STATUSES[:running],
        build_id: SecureRandom.uuid,
        progress_stage: DocumentBuild::PROGRESS_STAGES[:rendering_entries],
        progress_message: "Rendering pages 2/5",
        progress_current: 2,
        progress_total: 5,
        last_progress_at: Time.current
      )

      enqueued = false

      Documents::Generated::RunDocumentBuildJob.stub :perform_later, ->(*_args) { enqueued = true } do
        assert_no_difference("DocumentBuild.count") do
          post snapshot_event_documents_generated_url(@event, @document.logical_id)
        end
      end

      assert_redirected_to event_documents_generated_url(@event, @document.logical_id)
      assert_not enqueued
      assert_equal active_build.id, flash[:snapshot_build_id]
      assert_equal "Rendering pages 2/5", flash[:snapshot_build_message]
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

    test "show renders a live snapshot build toast for an active build" do
      active_build = @document.builds.create!(
        status: DocumentBuild::STATUSES[:running],
        build_id: SecureRandom.uuid,
        progress_stage: DocumentBuild::PROGRESS_STAGES[:rendering_entries],
        progress_message: "Rendering pages 2/5",
        progress_current: 2,
        progress_total: 5,
        last_progress_at: Time.current
      )

      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select ".flash-toast--build[data-build-status='running']", count: 1
      assert_select ".flash-toast--build[data-build-status-url='#{status_event_documents_generated_build_path(@event, @document.logical_id, active_build)}']", count: 1
      assert_select ".flash-toast--build .flash-toast__text[data-flash-toast-target='buildMessage']", text: "Rendering pages 2/5"
    end

    test "show renders a duplicate packet button before packet settings" do
      get event_documents_generated_url(@event, @document.logical_id)

      assert_response :success
      assert_select "form[action='#{duplicate_event_documents_generated_path(@event, @document.logical_id)}'] button[type='submit']", text: "Duplicate packet", count: 1
      assert_select "a[href='#{edit_event_documents_generated_path(@event, @document.logical_id)}']", text: "Packet settings", count: 1
      assert_operator @response.body.index("Duplicate packet"), :<, @response.body.index("Packet settings")
    end

    test "duplicate creates a new packet with copied placements and cloned editable sources" do
      @document.update!(client_visible: true, financial_portal_visible: true, packets_portal_visible: true)
      page_source = create_page_source(
        view_key: DocumentSegment::TEXT_PAGE_VIEW_KEY,
        title: "Planner Notes",
        options: { "body_markdown" => "Notes" }
      )
      group_document = create_group_document(title: "Design & Decor")
      group_source = GeneratedPacketSource.find_or_create_group_source!(@event, group_document)
      @document.packet_placements.create!(source: page_source, position: 1)
      @document.packet_placements.create!(source: group_source, position: 2)

      assert_difference -> { @event.documents.generated.packet_containers.where(storage_uri: nil).count }, 1 do
        assert_difference -> { GeneratedPacketPlacement.count }, 2 do
          assert_difference -> { GeneratedPacketSource.count }, 1 do
            post duplicate_event_documents_generated_url(@event, @document.logical_id)
          end
        end
      end

      duplicated = @event.documents.generated.packet_containers.where(storage_uri: nil, title: "New Generated Packet").order(:created_at).last
      assert_redirected_to event_documents_generated_url(@event, duplicated.logical_id)
      assert_not_equal @document.logical_id, duplicated.logical_id
      assert_equal @document.client_visible, duplicated.client_visible
      assert_equal @document.financial_portal_visible, duplicated.financial_portal_visible
      assert_equal @document.packets_portal_visible, duplicated.packets_portal_visible
      assert_equal @document.packet_schema_version, duplicated.packet_schema_version
      assert_equal @document.packet_container_kind, duplicated.packet_container_kind

      duplicated_placements = duplicated.packet_placements.includes(:source).ordered.to_a
      assert_equal [1, 2], duplicated_placements.map(&:position)
      assert_equal ["Planner Notes", "Design & Decor"], duplicated_placements.map(&:title)

      duplicated_page_source = duplicated_placements.first.source
      assert_not_equal page_source.id, duplicated_page_source.id
      assert_equal page_source.source_category, duplicated_page_source.source_category
      assert_equal page_source.kind, duplicated_page_source.kind
      assert_equal page_source.source_ref, duplicated_page_source.source_ref
      assert_equal page_source.spec, duplicated_page_source.spec
      assert_equal group_source.id, duplicated_placements.second.generated_packet_source_id
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
        source: create_page_source(view_key: "section_break", title: title, options: {}),
        position: 1
      )
      document
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
