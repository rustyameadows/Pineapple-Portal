require "test_helper"

class DocumentsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
    @event = events(:one)
    @document = documents(:contract_v1)
  end

  test "lists documents for event" do
    get event_documents_url(@event)
    assert_response :success
    assert_select "h1", text: "Files for #{@event.name}"
    assert_select ".documents-table__table"
    assert_select ".documents-table__row", minimum: 1
    assert_select ".documents-nav__link", text: /Planner Uploads/
  end

  test "group view shows version metadata" do
    get packets_event_documents_url(@event)
    assert_response :success
    assert_select "h1", text: "Packets"
    assert_select ".documents-table__cell--version", text: /v2/i
  end

  test "uploads new document" do
    assert_difference("Document.count") do
      post event_documents_url(@event), params: {
        document: {
          title: "Run Sheet",
          storage_uri: "documents/run-sheet-v1.pdf",
          checksum: "checksum-runsheet",
          size_bytes: 2048,
          content_type: "application/pdf"
        }
      }
    end

    assert_redirected_to event_document_url(@event, Document.last)
  end

  test "creates new version" do
    assert_difference("Document.count") do
      post event_documents_url(@event), params: {
        document: {
          title: "Production Contract",
          storage_uri: "documents/contract-v2.pdf",
          checksum: "checksum-v2",
          size_bytes: 4096,
          content_type: "application/pdf",
          logical_id: @document.logical_id
        }
      }
    end

    assert_redirected_to event_document_url(@event, Document.last)
    assert_equal 2, Document.last.version
  end

  test "new version inherits source and visibility" do
    reference = documents(:welcome_packet_v2)

    assert_difference("Document.count") do
      post event_documents_url(@event), params: {
        document: {
          title: reference.title,
          storage_uri: "documents/packets/welcome-v3.pdf",
          checksum: "welcome-checksum-v3",
          size_bytes: 4096,
          content_type: "application/pdf",
          logical_id: reference.logical_id
        }
      }
    end

    new_document = Document.order(:created_at).last
    assert_equal "packet", new_document.source
    assert new_document.client_visible?
  end
end
