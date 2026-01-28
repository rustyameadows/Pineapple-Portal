require "test_helper"

class Client::DesignsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @event = events(:one)
    log_in_client_portal(users(:client_contact))
  end

  test "shows planner and client documents" do
    get client_event_designs_url(@event)
    assert_response :success
    assert_select ".client-designs__section-heading h2", text: "Shared Inspiration"
    assert_select ".client-designs__document-item strong a", text: /Design Packet/
    assert_select ".client-designs__tile-caption strong", text: "Mood Board"
  end

  test "client can upload document" do
    logical_id = SecureRandom.uuid

    assert_difference("Document.where(source: 'client_upload').count") do
      post client_event_designs_url(@event), params: {
        document: {
          title: "Client Inspiration",
          storage_uri: "documents/client-inspiration-v1.pdf",
          checksum: "client-inspiration-checksum",
          size_bytes: 1024,
          content_type: "application/pdf",
          logical_id: logical_id
        }
      }
    end

    assert_redirected_to client_event_designs_url(@event.portal_slug)

    created = Document.order(:created_at).last
    assert_equal "client_upload", created.source
    assert created.client_visible?
    assert_equal logical_id, created.logical_id
    assert_equal @event, created.event
  end

  test "invalid upload renders errors" do
    assert_no_difference("Document.count") do
      post client_event_designs_url(@event), params: { document: { title: "" } }
    end

    assert_response :unprocessable_content
    assert_select ".client-designs__form-errors"
  end
end
