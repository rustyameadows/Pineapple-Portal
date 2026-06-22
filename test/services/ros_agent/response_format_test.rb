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
