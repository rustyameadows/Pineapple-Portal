require "test_helper"

module RosAgent
  class ChangePlanApplierTest < ActiveSupport::TestCase
    class FakeTask
      attr_accessor :event, :status, :approved_plan_version, :current_plan_version,
                    :applied_at, :applied_operation_counts, :validation_json, :preview_json
      attr_reader :appended_events

      def initialize(event:, status:, approved_plan_version:, current_plan_version:)
        @event = event
        @status = status
        @approved_plan_version = approved_plan_version
        @current_plan_version = current_plan_version
        @appended_events = []
      end

      def append_event!(**payload)
        @appended_events << payload
      end
    end

    setup do
      @event = events(:one)
      @calendar = event_calendars(:run_of_show)
    end

    test "refuses to write before task approval" do
      task = FakeTask.new(
        event: @event,
        status: "draft",
        approved_plan_version: 1,
        current_plan_version: 1
      )

      result = ChangePlanApplier.new(
        task: task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-1",
              "operation_type" => "create_item",
              "summary" => "Add guest arrival block",
              "risk_level" => "low",
              "attributes" => { "title" => "Guest Arrival" }
            }
          ]
        }
      ).call

      assert_not result.applied?
      assert_includes result.errors, "Task must be approved before applying a ROS change plan."
      assert_not CalendarItem.exists?(title: "Guest Arrival")
    end

    test "applies approved create and tag operations transactionally" do
      task = FakeTask.new(
        event: @event,
        status: "approved",
        approved_plan_version: 3,
        current_plan_version: 3
      )
      scheduler = Minitest::Mock.new
      scheduler.expect(:call, true)

      result = Calendars::CascadeScheduler.stub(:new, ->(calendar) {
        assert_equal @calendar, calendar
        scheduler
      }) do
        ChangePlanApplier.new(
          task: task,
          calendar: @calendar,
          plan_hash: {
            "operations" => [
              {
                "operation_id" => "create-tag-1",
                "operation_type" => "create_tag",
                "summary" => "Add logistics tag",
                "risk_level" => "low",
                "name" => "Logistics",
                "color_token" => "#336699"
              },
              {
                "operation_id" => "create-item-1",
                "operation_type" => "create_item",
                "summary" => "Add guest arrival block",
                "risk_level" => "low",
                "attributes" => {
                  "title" => "Guest Arrival",
                  "starts_at" => "2025-10-01T14:30:00Z",
                  "duration_minutes" => 30,
                  "vendor_name" => "DJ TBD",
                  "location_name" => "Front Drive"
                }
              },
              {
                "operation_id" => "assign-tags-1",
                "operation_type" => "assign_tags",
                "summary" => "Tag the new guest arrival block",
                "risk_level" => "low",
                "target_item_operation_id" => "create-item-1",
                "tag_names" => ["Logistics"]
              }
            ]
          }
        ).call
      end

      scheduler.verify

      assert_predicate result, :applied?
      assert_equal "applied", task.status
      assert_instance_of Time, task.applied_at
      assert_equal({ create_count: 1, update_count: 0, delete_count: 0, create_tag_count: 1, assign_tag_count: 1 }, task.applied_operation_counts)
      assert_equal 1, task.appended_events.size

      item = @calendar.calendar_items.find_by!(title: "Guest Arrival")
      tag = @calendar.event_calendar_tags.find_by!(name: "Logistics")

      assert_equal "Front Drive", item.location_name
      assert_equal "DJ TBD", item.vendor_name
      assert_includes item.event_calendar_tag_ids, tag.id
    end

    test "applies top-level tags on create item operations" do
      task = FakeTask.new(
        event: @event,
        status: "approved",
        approved_plan_version: 3,
        current_plan_version: 3
      )
      vendor_tag = event_calendar_tags(:vendor)
      day_of_tag = event_calendar_tags(:day_of)

      result = ChangePlanApplier.new(
        task: task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-item-1",
              "operation_type" => "create_item",
              "summary" => "Add production load-in.",
              "risk_level" => "low",
              "tag_ids" => [vendor_tag.id],
              "tag_names" => [day_of_tag.name],
              "item_attributes" => {
                "title" => "Production Load-In",
                "starts_at" => "2025-10-01T14:30:00Z"
              }
            }
          ]
        }
      ).call

      assert_predicate result, :applied?
      assert_equal({ create_count: 1, update_count: 0, delete_count: 0, create_tag_count: 0, assign_tag_count: 1 }, task.applied_operation_counts)

      item = @calendar.calendar_items.find_by!(title: "Production Load-In")

      assert_equal [day_of_tag.id, vendor_tag.id].sort, item.event_calendar_tag_ids.sort
    end

    test "applies date-only starts in the event calendar timezone" do
      @calendar.update!(timezone: "America/New_York")
      task = FakeTask.new(
        event: @event,
        status: "approved",
        approved_plan_version: 3,
        current_plan_version: 3
      )

      result = ChangePlanApplier.new(
        task: task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-item-1",
              "operation_type" => "create_item",
              "summary" => "Add all-day production item.",
              "risk_level" => "low",
              "item_attributes" => {
                "title" => "Production Load-In",
                "starts_at" => "2026-07-12"
              }
            }
          ]
        }
      ).call

      assert_predicate result, :applied?
      item = @calendar.calendar_items.find_by!(title: "Production Load-In")
      local_start = item.starts_at.in_time_zone(@calendar.timezone)

      assert_equal "2026-07-12 00:00", local_start.strftime("%Y-%m-%d %H:%M")
    end

    test "applies explicit local datetimes in the event calendar timezone" do
      @calendar.update!(timezone: "America/New_York")
      task = FakeTask.new(
        event: @event,
        status: "approved",
        approved_plan_version: 3,
        current_plan_version: 3
      )

      result = ChangePlanApplier.new(
        task: task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-item-1",
              "operation_type" => "create_item",
              "summary" => "Add lift delivery.",
              "risk_level" => "low",
              "item_attributes" => {
                "title" => "Lift Delivery",
                "starts_at" => "2026-07-12T09:00:00"
              }
            }
          ]
        }
      ).call

      assert_predicate result, :applied?
      item = @calendar.calendar_items.find_by!(title: "Lift Delivery")
      local_start = item.starts_at.in_time_zone(@calendar.timezone)

      assert_equal "2026-07-12 09:00", local_start.strftime("%Y-%m-%d %H:%M")
    end

    test "omits nil non-null attributes so calendar item defaults apply" do
      task = FakeTask.new(
        event: @event,
        status: "approved",
        approved_plan_version: 3,
        current_plan_version: 3
      )

      result = ChangePlanApplier.new(
        task: task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-item-1",
              "operation_type" => "create_item",
              "summary" => "Add guest arrival block",
              "risk_level" => "low",
              "item_attributes" => {
                "title" => "Guest Arrival With Null Status",
                "starts_at" => "2025-10-01T14:30:00Z",
                "status" => nil,
                "relative_offset_minutes" => nil,
                "relative_before" => nil,
                "relative_to_anchor_end" => nil,
                "locked" => nil
              }
            }
          ]
        }
      ).call

      assert_predicate result, :applied?
      item = @calendar.calendar_items.find_by!(title: "Guest Arrival With Null Status")
      assert_equal "planned", item.status
      assert_equal 0, item.relative_offset_minutes
      assert_equal false, item.relative_before
      assert_equal false, item.relative_to_anchor_end
      assert_equal false, item.locked
    end

    test "keeps nullable clears on updates while omitting nil non-null attributes" do
      item = calendar_items(:ceremony)
      item.update!(notes: "Clear me", relative_before: true)
      task = FakeTask.new(
        event: @event,
        status: "approved",
        approved_plan_version: 3,
        current_plan_version: 3
      )

      result = ChangePlanApplier.new(
        task: task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "update-item-1",
              "operation_type" => "update_item",
              "summary" => "Clear notes but leave relative flags alone",
              "risk_level" => "low",
              "target_item_id" => item.id,
              "item_attributes" => {
                "notes" => nil,
                "relative_before" => nil
              }
            }
          ]
        }
      ).call

      assert_predicate result, :applied?
      item.reload
      assert_nil item.notes
      assert_equal true, item.relative_before
    end

    test "rolls back all changes when a later operation fails" do
      task = FakeTask.new(
        event: @event,
        status: "approved",
        approved_plan_version: 4,
        current_plan_version: 4
      )

      result = ChangePlanApplier.new(
        task: task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-item-1",
              "operation_type" => "create_item",
              "summary" => "Add guest arrival block",
              "risk_level" => "low",
              "attributes" => {
                "title" => "Guest Arrival",
                "starts_at" => "2025-10-01T14:30:00Z"
              }
            },
            {
              "operation_id" => "create-tag-1",
              "operation_type" => "create_tag",
              "summary" => "Create a duplicate vendor tag",
              "risk_level" => "low",
              "name" => "Vendor"
            }
          ]
        }
      ).call

      assert_not result.applied?
      assert_includes result.errors, "Name has already been taken"
      assert_not CalendarItem.exists?(title: "Guest Arrival")
    end

    test "refuses high-risk plans that were not acknowledged" do
      task = agent_tasks(:draft_task)
      task.update!(
        status: "approved",
        current_plan_version: 5,
        approved_plan_version: 5,
        validation_json: { "blocking_errors" => [] },
        preview_json: { "high_risk_operation_ids" => ["delete-1"] }
      )

      result = ChangePlanApplier.new(
        task: task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "delete-1",
              "operation_type" => "delete_item",
              "summary" => "Delete ceremony.",
              "risk_level" => "high",
              "target_item_id" => calendar_items(:ceremony).id
            }
          ]
        }
      ).call

      assert_not result.applied?
      assert_includes result.errors, "High-risk operations must be acknowledged before applying a ROS change plan."
    end
  end
end
