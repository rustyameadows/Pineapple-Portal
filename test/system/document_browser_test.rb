require "application_system_test_case"

class DocumentBrowserTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @upload_document = documents(:contract_v1)
    @client_image_document = documents(:client_inspo_board)

    @event.documents.create!(
      title: "Budget Sheet",
      storage_uri: "documents/budget-sheet-v1.pdf",
      checksum: "budget-sheet-checksum-v1",
      size_bytes: 1024,
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: true,
      content_type: "application/pdf",
      source: "staff_upload",
      created_at: 3.days.ago,
      updated_at: 2.days.ago
    )

    @zebra_generated_document = @event.documents.create!(
      title: "Zebra Packet",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: false,
      source: "packet",
      client_visible: false,
      built_by_user: users(:one)
    )

    @event.documents.create!(
      title: "Zebra Packet",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: @zebra_generated_document.logical_id,
      version: 2,
      is_latest: true,
      source: "packet",
      client_visible: false,
      built_by_user: users(:one),
      storage_uri: "documents/zebra-packet-v2.pdf",
      checksum: "zebra-packet-checksum-v2",
      checksum_sha256: "zebra-packet-sha256-v2",
      size_bytes: 3072,
      content_type: "application/pdf",
      updated_at: 4.days.ago
    )

    @generated_document = @event.documents.create!(
      title: "Client Packet",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: false,
      source: "packet",
      client_visible: true,
      built_by_user: users(:one)
    )
  end

  test "upload browser defaults to table, filters by title, toggles to grid, and opens the document page" do
    login_as_planner
    visit staff_uploads_event_documents_path(@event)

    assert_equal ["Production Contract", "Budget Sheet"], visible_table_titles
    assert_no_selector ".documents-browser__card", text: "Production Contract"

    find("button[data-sort-key='size']").click
    assert_selector "th[data-sort-key='size'][aria-sort='ascending']"
    assert_equal ["Budget Sheet", "Production Contract"], visible_table_titles

    find("button[data-sort-key='size']").click
    assert_selector "th[data-sort-key='size'][aria-sort='descending']"
    assert_equal ["Production Contract", "Budget Sheet"], visible_table_titles

    click_button "Grid"
    assert_equal ["Production Contract", "Budget Sheet"], visible_grid_titles

    click_button "Table"
    fill_in "Search", with: "PRODUCTION"
    assert_equal ["Production Contract"], visible_table_titles
    assert_no_selector ".documents-browser__row", text: "Budget Sheet"
    assert_highlight_state(expected_present: true, minimum_range_count: 2)

    fill_in "Search", with: ""
    assert_equal ["Production Contract", "Budget Sheet"], visible_table_titles
    assert_highlight_state(expected_present: false)

    fill_in "Search", with: "PRODUCTION"

    find(".documents-browser__row", text: "Production Contract").click
    assert_current_path event_document_path(@event, @upload_document)

    visit staff_uploads_event_documents_path(@event)
    click_button "Grid"
    assert_equal ["Production Contract", "Budget Sheet"], visible_grid_titles

    fill_in "Search", with: "production"
    assert_highlight_state(expected_present: true, minimum_range_count: 2)
    find(".documents-browser__card", text: "Production Contract").click
    assert_current_path event_document_path(@event, @upload_document)
  end

  test "image upload grid card defers src until grid mode is shown" do
    login_as_planner
    visit client_uploads_event_documents_path(@event)

    card = find(".documents-browser__card", text: @client_image_document.title, visible: :all)
    image = card.find("img", visible: :all)
    expected_media_url = download_event_document_path(@event, @client_image_document)

    assert_equal expected_media_url, image[:'data-media-url']
    assert_nil image[:src]

    click_button "Grid"

    card = find(".documents-browser__card", text: @client_image_document.title, visible: :all)
    image = card.find("img", visible: :all)

    assert_equal expected_media_url, image[:'data-media-url']
    assert_equal expected_media_url, page.evaluate_script(<<~JS)
      (() => {
        const image = document.querySelector("img[data-media-url=#{expected_media_url.inspect}]")
        return image ? image.getAttribute("src") : null
      })()
    JS
  end

  test "generated packet browser defaults to table, toggles to grid, and opens the builder page" do
    login_as_planner
    visit event_documents_generated_index_path(@event)

    assert_equal ["Client Packet", "Zebra Packet"], visible_table_titles
    assert_no_selector ".documents-browser__card", text: "Client Packet"

    find("button[data-sort-key='title']").click
    assert_selector "th[data-sort-key='title'][aria-sort='ascending']"
    assert_equal ["Client Packet", "Zebra Packet"], visible_table_titles

    find("button[data-sort-key='title']").click
    assert_selector "th[data-sort-key='title'][aria-sort='descending']"
    assert_equal ["Zebra Packet", "Client Packet"], visible_table_titles

    find("button[data-sort-key='compiled_versions']").click
    assert_selector "th[data-sort-key='compiled_versions'][aria-sort='ascending']"
    assert_equal ["Client Packet", "Zebra Packet"], visible_table_titles

    find("button[data-sort-key='compiled_versions']").click
    assert_selector "th[data-sort-key='compiled_versions'][aria-sort='descending']"
    assert_equal ["Zebra Packet", "Client Packet"], visible_table_titles

    click_button "Grid"
    assert_equal ["Zebra Packet", "Client Packet"], visible_grid_titles

    click_button "Table"

    fill_in "Search", with: "client"
    assert_equal ["Client Packet"], visible_table_titles
    assert_highlight_state(expected_present: true, minimum_range_count: 2)

    find(".documents-browser__row", text: "Client Packet").click
    assert_current_path event_documents_generated_path(@event, @generated_document.logical_id)

    visit event_documents_generated_index_path(@event)
    click_button "Grid"
    assert_selector ".documents-browser__card", text: "Client Packet"

    fill_in "Search", with: "CLIENT"
    assert_highlight_state(expected_present: true, minimum_range_count: 2)
    find(".documents-browser__card", text: "Client Packet").click
    assert_current_path event_documents_generated_path(@event, @generated_document.logical_id)
  end

  private

  def login_as_planner
    visit login_path
    fill_in "Email", with: users(:one).email
    fill_in "Password", with: "password123"
    click_button "Log In"
    assert_text "Your Active Events"
  end

  def visible_table_titles
    all(".documents-browser__row", visible: :visible).map do |row|
      row.find("[data-document-browser-target='titleText']", visible: :visible).text
    end
  end

  def visible_grid_titles
    all(".documents-browser__card", visible: :visible).map do |card|
      card.find("[data-document-browser-target='titleText']", visible: :visible).text
    end
  end

  def assert_highlight_state(expected_present:, minimum_range_count: 1)
    supported = page.evaluate_script(<<~JS)
      Boolean(window.CSS && CSS.highlights && typeof CSS.highlights.has === "function" && typeof window.Highlight === "function")
    JS

    return unless supported

    if expected_present
      assert page.evaluate_script("CSS.highlights.has('document-browser-search-match')")
      assert_operator page.evaluate_script("CSS.highlights.get('document-browser-search-match').size"), :>=, minimum_range_count
    else
      assert_not page.evaluate_script("CSS.highlights.has('document-browser-search-match')")
    end
  end
end
