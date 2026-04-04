require "test_helper"

module Documents
  class GeneratedRoutesTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @logical_id = "11111111-1111-1111-1111-111111111111"
    end

    test "packet library and default packet routes resolve" do
      assert_routing(
        { method: "get", path: event_documents_generated_index_path(@event) },
        controller: "documents/generated",
        action: "index",
        event_id: @event.id.to_s
      )

      assert_routing(
        { method: "get", path: library_event_documents_generated_index_path(@event) },
        controller: "documents/generated",
        action: "library",
        event_id: @event.id.to_s
      )

      assert_routing(
        { method: "post", path: add_default_packets_event_documents_generated_index_path(@event) },
        controller: "documents/generated",
        action: "add_default_packets",
        event_id: @event.id.to_s
      )
    end

    test "packet settings and delete routes resolve" do
      assert_routing(
        { method: "get", path: edit_event_documents_generated_path(@event, @logical_id) },
        controller: "documents/generated",
        action: "edit",
        event_id: @event.id.to_s,
        logical_id: @logical_id
      )

      assert_routing(
        { method: "delete", path: event_documents_generated_path(@event, @logical_id) },
        controller: "documents/generated",
        action: "destroy",
        event_id: @event.id.to_s,
        logical_id: @logical_id
      )
    end

    test "working pdf, working status, and snapshot routes resolve to the generated packet builder" do
      assert_routing(
        { method: "get", path: working_pdf_event_documents_generated_path(@event, @logical_id) },
        controller: "documents/generated",
        action: "working_pdf",
        event_id: @event.id.to_s,
        logical_id: @logical_id
      )

      assert_routing(
        { method: "get", path: working_status_event_documents_generated_path(@event, @logical_id) },
        controller: "documents/generated",
        action: "working_status",
        event_id: @event.id.to_s,
        logical_id: @logical_id
      )

      assert_routing(
        { method: "post", path: snapshot_event_documents_generated_path(@event, @logical_id) },
        controller: "documents/generated",
        action: "compile",
        event_id: @event.id.to_s,
        logical_id: @logical_id
      )
    end
  end
end
