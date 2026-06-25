require "test_helper"

class LabsControllerTest < ActionDispatch::IntegrationTest
  setup do
    log_in_as(users(:one))
  end

  test "ros agent response chain demo renders all major sections" do
    get labs_ros_agent_response_chain_path

    assert_response :success
    assert_select "p.event-section__eyebrow", text: "Labs"
    assert_select "h1", text: "ROS Agent Response Chain"
    assert_select "#lab-agent-status"
    assert_select "#lab-planning-questions"
    assert_select "#lab-draft-ros"
    assert_select "#lab-final-plan"
    assert_select "#lab-apply-review"
    assert_select "#lab-trace-artifacts"
    assert_select ".labs-agent-chain__step", minimum: 5
    assert_select "table.event-table", minimum: 5
  end
end
