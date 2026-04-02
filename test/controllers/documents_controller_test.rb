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
  end

  test "staff and client upload pages render the shared document browser" do
    get staff_uploads_event_documents_url(@event)
    assert_response :success
    assert_select "[data-controller='document-browser']", count: 1
    assert_select ".documents-browser__row", text: /Production Contract/

    get client_uploads_event_documents_url(@event)
    assert_response :success
    assert_select "[data-controller='document-browser']", count: 1
    assert_select ".documents-browser__row", text: /Mood Board/
  end

  test "hides packet source documents by default and allows explicit toggle" do
    definition = @event.documents.create!(
      title: "Packet Builder",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: false,
      source: "packet"
    )

    DocumentSegment.create!(
      document_logical_id: definition.logical_id,
      position: 1,
      kind: DocumentSegment::KINDS[:pdf_asset],
      title: "Contract Segment",
      source_ref: {
        "document_id" => @document.id,
        "logical_id" => @document.logical_id
      },
      spec: { "kind" => DocumentSegment::KINDS[:pdf_asset] }
    )

    get event_documents_url(@event)
    assert_response :success
    assert_select ".documents-table__title-link", text: "Production Contract", count: 0

    get event_documents_url(@event, params: { include_packet_components: "1" })
    assert_response :success
    assert_select ".documents-table__title-link", text: "Production Contract"
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

  test "rejects client upload source from staff document form" do
    assert_no_difference("Document.count") do
      post event_documents_url(@event), params: {
        document: {
          title: "Blocked Client Upload",
          storage_uri: "documents/blocked-client-upload-v1.pdf",
          checksum: "blocked-client-upload-checksum-v1",
          size_bytes: 2048,
          content_type: "application/pdf",
          source: "client_upload"
        }
      }
    end

    assert_response :unprocessable_content
    assert_select ".errors li", text: /client uploads can only be created from the client portal/i
  end

  test "updates packets portal visibility for compiled version and returns to builder" do
    logical_id = SecureRandom.uuid
    generated_document = @event.documents.create!(
      title: "Generated Packet v2",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: logical_id,
      version: 2,
      is_latest: true,
      source: "packet",
      storage_uri: "documents/generated-packet-v2.pdf",
      checksum: "generated-packet-checksum-v2",
      checksum_sha256: "generated-packet-sha256-v2",
      size_bytes: 4096,
      content_type: "application/pdf",
      packets_portal_visible: false
    )

    patch event_document_url(@event, generated_document, return_to: event_documents_generated_path(@event, logical_id)), params: {
      document: {
        packets_portal_visible: "1"
      }
    }

    assert_redirected_to event_documents_generated_url(@event, logical_id)
    assert generated_document.reload.packets_portal_visible?
  end

  test "planner download redirects to storage" do
    captured = nil
    storage = Object.new
    storage.define_singleton_method(:presigned_download_url) do |**kwargs|
      captured = kwargs
      "https://files.example.com/contract.pdf"
    end

    R2::Storage.stub :new, storage do
      get download_event_document_url(@event, @document)
      assert_redirected_to "https://files.example.com/contract.pdf"
    end

    assert_equal({ key: @document.storage_uri }, captured)
  end

  test "client download redirects to storage" do
    delete logout_url
    log_in_client_portal(users(:client_contact))

    captured = nil
    storage = Object.new
    storage.define_singleton_method(:presigned_download_url) do |**kwargs|
      captured = kwargs
      "https://files.example.com/contract.pdf"
    end

    R2::Storage.stub :new, storage do
      get download_event_document_url(@event, @document)
      assert_redirected_to "https://files.example.com/contract.pdf"
    end

    assert_equal({ key: @document.storage_uri }, captured)
  end
end
