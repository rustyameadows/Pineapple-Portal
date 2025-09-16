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
    original_new = R2::Storage.method(:new)

    begin
      R2::Storage.define_singleton_method(:new) { storage }
      post presign_event_documents_url(@event), params: { filename: "contract.pdf" }, as: :json
    ensure
      R2::Storage.define_singleton_method(:new, &original_new)
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "https://example.com/upload", body["upload_url"]
    assert body["storage_uri"].include?(@event.id.to_s)
    assert_equal 1, body["version"]
    assert_equal "application/octet-stream", body["content_type"]
    assert storage.args[:key].present?
  end

  test "returns next version when logical id provided" do
    existing = documents(:contract_v1)
    storage = StubStorage.new
    original_new = R2::Storage.method(:new)

    begin
      R2::Storage.define_singleton_method(:new) { storage }
      post presign_event_documents_url(@event), params: {
        filename: "contract.pdf",
        logical_id: existing.logical_id,
        content_type: "application/pdf"
      }, as: :json
    ensure
      R2::Storage.define_singleton_method(:new, &original_new)
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal existing.logical_id, body["logical_id"]
    assert_equal 2, body["version"]
    assert_equal "application/pdf", body["content_type"]
  end
end
