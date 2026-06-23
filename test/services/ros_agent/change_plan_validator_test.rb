require "test_helper"

module RosAgent
  class ChangePlanValidatorTest < ActiveSupport::TestCase
    TaskStub = Struct.new(:event, keyword_init: true)

    setup do
      @event = events(:one)
      @calendar = event_calendars(:run_of_show)
      @task = TaskStub.new(event: @event)
    end

    test "accepts a minimal create item operation" do
      result = ChangePlanValidator.new(
        task: @task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-1",
              "operation_type" => "create_item",
              "summary" => "Add guest arrival block",
              "risk_level" => "low",
              "attributes" => {
                "title" => "Guest Arrival",
                "starts_at" => "2025-10-01T14:30:00Z"
              }
            }
          ]
        }
      ).call

      assert_predicate result, :valid?
      assert_empty result.blocking_errors
      assert_empty result.high_risk_operation_ids
    end

    test "blocks existing item operations outside the task event calendar" do
      other_calendar = events(:two).event_calendars.create!(
        name: "Run of Show",
        timezone: "UTC",
        kind: EventCalendar::KINDS[:master]
      )
      foreign_item = other_calendar.calendar_items.create!(
        title: "Foreign Item",
        starts_at: Time.utc(2025, 11, 15, 12, 0, 0),
        duration_minutes: 30,
        position: 0
      )

      result = ChangePlanValidator.new(
        task: @task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "update-1",
              "operation_type" => "update_item",
              "summary" => "Move a different event item",
              "risk_level" => "medium",
              "target_item_id" => foreign_item.id,
              "attributes" => { "starts_at" => "2025-10-01T16:00:00Z" }
            }
          ]
        }
      ).call

      assert_not result.valid?
      assert_includes result.blocking_errors, "Operation update-1 targets an item outside this run of show calendar."
    end

    test "treats delete operations as high risk" do
      result = ChangePlanValidator.new(
        task: @task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "delete-1",
              "operation_type" => "delete_item",
              "summary" => "Remove reception",
              "risk_level" => "medium",
              "target_item_id" => calendar_items(:reception).id
            }
          ]
        }
      ).call

      assert_predicate result, :valid?
      assert_includes result.high_risk_operation_ids, "delete-1"
      assert_includes result.warnings, "Operation delete-1 deletes an existing item."
    end

    test "requires a title for created items" do
      result = ChangePlanValidator.new(
        task: @task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-1",
              "operation_type" => "create_item",
              "summary" => "Add an untitled row",
              "risk_level" => "low",
              "attributes" => {
                "starts_at" => "2025-10-01T14:30:00Z"
              }
            }
          ]
        }
      ).call

      assert_not result.valid?
      assert_includes result.blocking_errors, "Operation create-1 must provide attributes.title for create_item."
    end

    test "blocks invalid calendar item status values" do
      result = ChangePlanValidator.new(
        task: @task,
        calendar: @calendar,
        plan_hash: {
          "operations" => [
            {
              "operation_id" => "create-1",
              "operation_type" => "create_item",
              "summary" => "Add a row with a bad status",
              "risk_level" => "low",
              "item_attributes" => {
                "title" => "Guest Arrival",
                "status" => "confirmed"
              }
            }
          ]
        }
      ).call

      assert_not result.valid?
      assert_includes result.blocking_errors, "Operation create-1 has invalid item_attributes.status confirmed."
    end
  end
end
