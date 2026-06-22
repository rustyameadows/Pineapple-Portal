require "test_helper"

module RosAgent
  class ChangePlanPreviewTest < ActiveSupport::TestCase
    TaskStub = Struct.new(:event, keyword_init: true)

    setup do
      @event = events(:one)
      @calendar = event_calendars(:run_of_show)
      @task = TaskStub.new(event: @event)
    end

    test "builds preview rows and counts for a valid create plan" do
      preview = ChangePlanPreview.new(
        task: @task,
        calendar: @calendar,
        plan_hash: {
          "assumptions" => ["Use the existing venue timing."],
          "warnings" => ["Planner should confirm shuttle timing."],
          "operations" => [
            {
              "operation_id" => "create-1",
              "operation_type" => "create_item",
              "summary" => "Add guest arrival block",
              "risk_level" => "low",
              "attributes" => {
                "title" => "Guest Arrival",
                "starts_at" => "2025-10-01T14:30:00Z",
                "duration_minutes" => 30,
                "location_name" => "Front Drive"
              }
            }
          ]
        }
      ).call

      assert_equal 1, preview[:create_count]
      assert_equal 0, preview[:update_count]
      assert_equal 0, preview[:delete_count]
      assert_equal 0, preview[:tag_change_count]
      assert_equal 1, preview[:time_change_count]
      assert_equal ["Use the existing venue timing."], preview[:assumptions]
      assert_equal ["Planner should confirm shuttle timing."], preview[:warnings]
      assert_empty preview[:high_risk_operation_ids]

      row = preview.dig(:grouped_preview_rows, :creates).first
      assert_equal "create-1", row[:operation_id]
      assert_equal "Guest Arrival", row[:after][:title]
      assert_equal "Front Drive", row[:after][:location_name]
    end
  end
end
