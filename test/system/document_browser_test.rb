require "application_system_test_case"

class DocumentBrowserTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @upload_document = documents(:contract_v1)

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

    assert_selector ".documents-browser__row", text: "Production Contract"
    assert_selector ".documents-browser__row", text: "Budget Sheet"
    assert_no_selector ".documents-browser__card", text: "Production Contract"

    fill_in "Search", with: "PRODUCTION"
    assert_selector ".documents-browser__row", text: "Production Contract"
    assert_no_selector ".documents-browser__row", text: "Budget Sheet"

    find(".documents-browser__row", text: "Production Contract").click
    assert_current_path event_document_path(@event, @upload_document)

    visit staff_uploads_event_documents_path(@event)
    click_button "Grid"
    assert_selector ".documents-browser__card", text: "Production Contract"

    fill_in "Search", with: "production"
    find(".documents-browser__card", text: "Production Contract").click
    assert_current_path event_document_path(@event, @upload_document)
  end

  test "generated packet browser defaults to table, toggles to grid, and opens the builder page" do
    login_as_planner
    visit event_documents_generated_index_path(@event)

    assert_selector ".documents-browser__row", text: "Client Packet"
    assert_no_selector ".documents-browser__card", text: "Client Packet"

    fill_in "Search", with: "client"
    assert_selector ".documents-browser__row", text: "Client Packet"

    find(".documents-browser__row", text: "Client Packet").click
    assert_current_path event_documents_generated_path(@event, @generated_document.logical_id)

    visit event_documents_generated_index_path(@event)
    click_button "Grid"
    assert_selector ".documents-browser__card", text: "Client Packet"

    fill_in "Search", with: "CLIENT"
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
end
