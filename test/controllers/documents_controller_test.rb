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

  test "document show keeps attachments list but omits attachment creation UI" do
    get event_document_url(@event, @document)

    assert_response :success
    assert_select ".documents-show__heading", text: "Attachments"
    assert_select ".documents-show__heading", text: "Attach to…", count: 0
    assert_select "input[name='attachment[entity_type]']", count: 0
    assert_select "input[name='attachment[file_upload_title]']", count: 0
    assert_select "input[type='submit'][value='Add Attachment']", count: 0
    assert_no_match(/data-attachment-upload-form/, response.body)
    assert_no_match(/performDirectUpload/, response.body)
  end

  test "client upload page defers image media until grid mode is used" do
    expected_media_url = download_event_document_path(@event, documents(:client_inspo_board))
    download_calls = 0
    storage = Object.new
    storage.define_singleton_method(:download) do |*|
      download_calls += 1
      nil
    end
    storage.define_singleton_method(:presigned_download_url) do |**|
      "https://files.example.com/mood-board.png"
    end

    R2::Storage.stub :new, storage do
      get client_uploads_event_documents_url(@event)
    end

    assert_response :success
    assert_equal 0, download_calls
    assert_select ".documents-browser__card-art img.documents-browser__card-image[data-media-url='#{expected_media_url}']", count: 1
    assert_select ".documents-browser__card-art img[src]", count: 0
    assert_no_match(/data:image\//, response.body)
  end

  test "planner uploads include packet docs and packet docs view lists uploads used in packets" do
    definition = @event.documents.create!(
      title: "Family Packet",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: false,
      source: "packet",
      packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed]
    )
    source = GeneratedPacketSource.find_or_create_upload_source!(@event, @document)
    definition.packet_placements.create!(source: source, position: 1)

    get staff_uploads_event_documents_url(@event)
    assert_response :success
    assert_select ".documents-browser__row", text: /Production Contract/
    assert_no_match(/packet source document/, response.body)

    get packet_docs_event_documents_url(@event)
    assert_response :success
    assert_select "h1", text: "Packet Docs"
    assert_operator response.body.index("Your Uploads"), :<, response.body.index("Packet Docs")
    assert_operator response.body.index("Packet Docs"), :<, response.body.index("Client Uploads")
    assert_select ".documents-browser__sort-button", text: /Latest version updated at/
    assert_select ".documents-browser__row", text: /Production Contract/
    assert_select ".documents-browser__row", text: /Family Packet/
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

  test "creating replacement version does not enqueue packet rebuilds" do
    working_refresh_calls = []
    broad_refresh_calls = []

    Documents::Generated::WorkingCopyRefresh.stub :enqueue, ->(*args, **kwargs) { working_refresh_calls << [args, kwargs] } do
      Documents::Generated::RefreshEventPacketCachesJob.stub :perform_later, ->(*args) { broad_refresh_calls << args } do
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
      end
    end

    assert_redirected_to event_document_url(@event, Document.last)
    assert_equal [], working_refresh_calls
    assert_equal [], broad_refresh_calls
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

  test "unauthenticated client download redirects to client login with return_to" do
    delete logout_url

    get download_event_document_url(@event, @document)

    assert_redirected_to client_login_url(return_to: download_event_document_path(@event, @document))
    assert_nil session[:user_id]
    assert_nil session[:client_user_id]
  end
end
