require "test_helper"

class GlobalAssetUploadsControllerTest < ActionDispatch::IntegrationTest
  class StubStorage
    attr_reader :args

    def presigned_upload_url(key:, content_type:)
      @args = { key: key, content_type: content_type }
      "https://example.com/global-upload"
    end
  end

  setup do
    log_in_as(users(:one))
  end

  test "returns presigned data for global asset upload" do
    storage = StubStorage.new

    R2::Storage.stub :new, storage do
      post global_assets_presign_url, params: {
        filename: "avatar.png",
        content_type: "image/png"
      }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_equal "https://example.com/global-upload", body["upload_url"]
    assert_equal "image/png", body["content_type"]
    assert_match(%r{\Aglobal-assets/[^/]+/avatar\.png\z}, body["storage_uri"])
    assert_equal "image/png", storage.args[:content_type]
  end

  test "sanitizes filename for global asset upload" do
    storage = StubStorage.new

    R2::Storage.stub :new, storage do
      post global_assets_presign_url, params: {
        filename: "Headshot Final!.png"
      }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)

    assert_match(%r{Headshot-Final-\.png\z}, body["storage_uri"])
  end
end
