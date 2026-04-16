require "test_helper"

class DocumentUploadsControllerTest < ActionDispatch::IntegrationTest
  class StubStorage
    attr_reader :args

    def presigned_upload_url(key:, content_type:)
      @args = { key: key, content_type: content_type }
      "https://example.com/upload"
    end
  end

  setup do
    log_in_as(users(:one))
    @event = events(:one)
  end

  test "returns presigned data for new document" do
    storage = StubStorage.new
    R2::Storage.stub :new, storage do
      post presign_event_documents_url(@event), params: { filename: "contract.pdf" }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "https://example.com/upload", body["upload_url"]
    assert body["storage_uri"].include?(@event.id.to_s)
    assert_equal 1, body["version"]
    assert_equal "application/octet-stream", body["content_type"]
    assert storage.args[:key].present?
  end

  test "returns presigned data for a client portal user with access to the event" do
    delete logout_url
    log_in_client_portal(users(:client_contact))

    storage = StubStorage.new
    R2::Storage.stub :new, storage do
      post presign_event_documents_url(@event), params: {
        filename: "mood-board.png",
        content_type: "image/png"
      }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "https://example.com/upload", body["upload_url"]
    assert body["storage_uri"].include?(@event.id.to_s)
    assert_equal "image/png", body["content_type"]
  end

  test "returns json when a signed-out request tries to presign" do
    delete logout_url

    post presign_event_documents_url(@event), params: {
      filename: "mood-board.png",
      content_type: "image/png"
    }, as: :json

    assert_response :unauthorized
    body = JSON.parse(response.body)

    assert_equal "Please sign in to upload files.", body["error"]
  end

  test "returns next version when logical id provided" do
    existing = documents(:contract_v1)
    storage = StubStorage.new
    R2::Storage.stub :new, storage do
      post presign_event_documents_url(@event), params: {
        filename: "contract.pdf",
        logical_id: existing.logical_id,
        content_type: "application/pdf"
      }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal existing.logical_id, body["logical_id"]
    assert_equal 2, body["version"]
    assert_equal "application/pdf", body["content_type"]
  end

  test "sanitizes filename in storage key" do
    storage = StubStorage.new

    R2::Storage.stub :new, storage do
      post presign_event_documents_url(@event), params: {
        filename: "Wholesale Prospecting Report?.pdf"
      }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_includes body["storage_uri"], "Wholesale-Prospecting-Report-.pdf"
  end
end
