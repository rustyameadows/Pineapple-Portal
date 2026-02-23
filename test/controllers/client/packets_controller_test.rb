require "test_helper"

module Client
  class PacketsControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      log_in_client_portal(users(:client_contact))
    end

    test "shows only packet-visible non-client-upload documents" do
      @event.documents.create!(
        title: "Generated Packet V1",
        doc_kind: Document::DOC_KINDS[:generated],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: true,
        source: "packet",
        storage_uri: "documents/generated-packet-v1.pdf",
        checksum: "generated-packet-checksum-v1",
        size_bytes: 4096,
        content_type: "application/pdf",
        packets_portal_visible: true
      )

      @event.documents.create!(
        title: "Client Upload Packet",
        doc_kind: Document::DOC_KINDS[:uploaded],
        logical_id: SecureRandom.uuid,
        version: 1,
        is_latest: true,
        source: "client_upload",
        storage_uri: "documents/client-upload-packet-v1.pdf",
        checksum: "client-upload-packet-checksum-v1",
        size_bytes: 1024,
        content_type: "application/pdf",
        client_visible: true,
        packets_portal_visible: true
      )

      get client_event_packets_url(@event)

      assert_response :success
      assert_select "h1", text: "Packets"
      assert_select "td", text: "Design Packet"
      assert_select "td", text: "Generated Packet V1"
      assert_select "td", text: "Client Upload Packet", count: 0
      assert_select "td", text: "Production Contract", count: 0
    end

    test "shows empty state when no packet documents are visible" do
      documents(:packet_brief).update!(packets_portal_visible: false)

      get client_event_packets_url(@event)

      assert_response :success
      assert_select ".client-placeholder", text: /No packets have been shared yet\./
    end
  end
end
