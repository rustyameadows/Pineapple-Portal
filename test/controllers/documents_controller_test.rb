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
