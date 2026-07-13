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

    test "working pdf, working status, rebuild, snapshot, and build status routes resolve to the generated packet builder" do
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

      assert_recognizes(
        {
          controller: "documents/generated",
          action: "rebuild_live",
          event_id: @event.id.to_s,
          logical_id: @logical_id
        },
        { method: "post", path: rebuild_live_event_documents_generated_path(@event, @logical_id) }
      )

      assert_recognizes(
        {
          controller: "documents/generated",
          action: "compile",
          event_id: @event.id.to_s,
          logical_id: @logical_id
        },
        { method: "post", path: snapshot_event_documents_generated_path(@event, @logical_id) }
      )

      assert_routing(
        { method: "get", path: status_event_documents_generated_build_path(@event, @logical_id, 12) },
        controller: "documents/generated/builds",
        action: "status",
        event_id: @event.id.to_s,
        generated_logical_id: @logical_id,
        id: "12"
      )
    end

    test "force build and relocation routes resolve to generated segments" do
      assert_routing(
        {
          method: "post",
          path: force_build_event_documents_generated_segment_path(@event, @logical_id, 42)
        },
        controller: "documents/generated/segments",
        action: "force_build",
        event_id: @event.id.to_s,
        generated_logical_id: @logical_id,
        id: "42"
      )

      assert_routing(
        {
          method: "patch",
          path: relocate_event_documents_generated_segments_path(@event, @logical_id)
        },
        controller: "documents/generated/segments",
        action: "relocate",
        event_id: @event.id.to_s,
        generated_logical_id: @logical_id
      )
    end
  end
end
