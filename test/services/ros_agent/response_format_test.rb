require "test_helper"

module RosAgent
  module Schemas
    class ResponseFormatTest < ActiveSupport::TestCase
      test "builds strict response format for draft-producing turns" do
        format = ResponseFormat.for_mode(:initial_run)

        assert_equal "json_schema", format[:type]
        assert_equal true, format[:strict]
        assert_equal "ros_agent_initial_run_response", format[:name]
        assert_equal false, format.dig(:schema, :additionalProperties)
        assert_includes format.dig(:schema, :properties, "state", :enum), "needs_input"
        assert_includes format.dig(:schema, :required), "draft_ros"
      end

      test "draft item schema keeps only approval essentials required" do
        format = ResponseFormat.for_mode(:initial_run)
        draft_item_schema = format.dig(:schema, :properties, "draft_ros", :anyOf, 0, :properties, "draft_items", :items)

        assert_equal %w[title timing duration_minutes confidence planner_review_needed source_refs], draft_item_schema[:required]
        refute_includes draft_item_schema[:properties].keys, "day_label"
        %w[notes location vendor_handling staff_handling tags].each do |key|
          assert_includes draft_item_schema[:properties].keys, key
          refute_includes draft_item_schema[:required], key
        end
      end

      test "builds strict final change plan response format" do
        format = ResponseFormat.for_mode(:request_final_plan)

        assert_equal true, format[:strict]
        assert_equal "ros_agent_request_final_plan_response", format[:name]
        assert_equal ["ready_for_review"], format.dig(:schema, :properties, "state", :enum)
        assert_includes format.dig(:schema, :properties, "operations", :items, :required), "item_attributes"
      end
    end
  end
end
