require "test_helper"

class UploadFailuresControllerTest < ActionDispatch::IntegrationTest
  test "accepts upload failure reports and emits a notification" do
    reported = []
    subscriber = ActiveSupport::Notifications.subscribe("direct_upload.failure_reported") do |_name, _start, _finish, _id, payload|
      reported << payload
    end

    post upload_failures_url, params: {
      scope: "document_form",
      stage: "storage_put",
      path: "/events/1/documents/new",
      event_id: 1,
      storage_uri: "documents/1/logical/v1/upload-sample.txt",
      logical_id: "logical-id-123",
      status: 0,
      response_text: "",
      message: "Upload to storage was blocked before it completed.",
      user_agent: "System Test Browser"
    }, as: :json

    assert_response :accepted
    assert_equal 1, reported.length
    assert_equal "document_form", reported.first[:scope]
    assert_equal "storage_put", reported.first[:stage]
    assert_equal "logical-id-123", reported.first[:logical_id]
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end
end
