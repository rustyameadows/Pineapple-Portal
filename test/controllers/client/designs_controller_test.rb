require "test_helper"

module Client
  class DesignsControllerTest < ActionDispatch::IntegrationTest
    setup do
      log_in_as(users(:client_contact))
      @event = events(:one)
    end

    test "shows planner and client uploads" do
      get client_event_designs_url(@event)
      assert_response :success
      assert_select "h2", text: "Planner uploads"
      assert_select ".client-upload__title", text: "Add new inspiration"
    end

    test "client can submit new inspiration" do
      assert_difference("Document.client_upload.count") do
        post client_event_designs_url(@event), params: {
          document: {
            title: "Ideas from Pinterest",
            storage_uri: "documents/client/pinterest-v1.png",
            checksum: "client-checksum-xyz",
            size_bytes: 1024,
            content_type: "image/png"
          }
        }
      end

      assert_redirected_to client_event_designs_url(@event)
      document = Document.last
      assert document.client_visible?
      assert_equal "client_upload", document.source
    end
  end
end
