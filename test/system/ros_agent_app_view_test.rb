require "application_system_test_case"

class RosAgentAppViewTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @task = agent_tasks(:draft_task)
  end

  test "agent assist app owns desktop scrolling and falls back on small screens" do
    @task.update!(
      status: "drafting",
      draft_ros_json: {
        "draft_days" => [
          {
            "label" => "Wedding Day",
            "entries" => [
              { "time_label" => "4:00 PM", "title" => "Ceremony" }
            ]
          }
        ]
      }
    )

    login_as_planner
    page.current_window.resize_to(1400, 900)
    visit event_ros_agent_task_path(@event, @task)

    assert_selector ".ros-agent-app"
    desktop_metrics = page.evaluate_script(<<~JS)
      (() => {
        const app = document.querySelector(".ros-agent-app")
        const canvasBody = document.querySelector(".ros-agent-canvas__body")
        return {
          documentScrollable: document.documentElement.scrollHeight > window.innerHeight + 2,
          appHeight: app.getBoundingClientRect().height,
          viewportHeight: window.innerHeight,
          canvasScrollOwner: canvasBody.scrollHeight >= canvasBody.clientHeight
        }
      })()
    JS

    assert_equal false, desktop_metrics["documentScrollable"]
    assert_in_delta desktop_metrics["viewportHeight"], desktop_metrics["appHeight"], 4
    assert_equal true, desktop_metrics["canvasScrollOwner"]

    page.current_window.resize_to(800, 700)
    small_metrics = page.evaluate_script(<<~JS)
      (() => ({
        documentScrollable: document.documentElement.scrollHeight > window.innerHeight + 2,
        appHeight: document.querySelector(".ros-agent-app").getBoundingClientRect().height,
        viewportHeight: window.innerHeight
      }))()
    JS

    assert_equal true, small_metrics["documentScrollable"]
    assert_operator small_metrics["appHeight"], :>, small_metrics["viewportHeight"]
  end

  test "typing a custom question answer selects the custom radio" do
    @task.update!(status: "needs_input")
    agent_task_question_batches(:open_questions).update!(
      questions_json: [
        {
          "key" => "date_mapping",
          "label" => "Date Mapping",
          "question" => "Should the source Saturday timeline map to the event wedding date?",
          "options" => [{ "value" => "map_saturday", "label" => "Map Saturday", "recommended" => true }],
          "freeform_allowed" => true
        }
      ]
    )

    login_as_planner
    visit event_ros_agent_task_path(@event, @task)

    fill_in "custom_answers[date_mapping]", with: "Use Sunday instead."

    assert_equal true, page.evaluate_script(<<~JS)
      document.querySelector("input[name='answers[date_mapping]'][value='__custom__']").checked
    JS
  end

  test "draft table scrolls horizontally through the canvas body" do
    @task.update!(
      status: "drafting",
      draft_ros_json: {
        "draft_days" => [
          {
            "label" => "Production Day",
            "entries" => [
              {
                "time_label" => "9:00 AM",
                "title" => "Tent Build",
                "timing" => { "kind" => "date", "starts_at" => "2026-07-20" },
                "duration_minutes" => 120,
                "notes" => "Confirm build details.",
                "location" => "Lawn",
                "vendor_handling" => "Skyline Tent Co.",
                "staff_handling" => "Production captain",
                "tags" => ["Production"],
                "confidence" => "high",
                "planner_review_needed" => "Confirm exact footprint.",
                "source_refs" => [{ "artifact" => "production.csv", "locator" => "row 4" }]
              }
            ]
          }
        ]
      }
    )

    login_as_planner
    page.current_window.resize_to(1400, 900)
    visit event_ros_agent_task_path(@event, @task)

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const body = document.querySelector(".ros-agent-canvas__body")
        const table = document.querySelector("#draft-ros > table.ros-agent-draft__table")
        return {
          bodyClientWidth: body.clientWidth,
          bodyScrollWidth: body.scrollWidth,
          innerShellCount: document.querySelectorAll("#draft-ros .ros-agent-draft__table-shell").length,
          tableWidth: table.getBoundingClientRect().width
        }
      })()
    JS

    assert_equal 0, metrics["innerShellCount"]
    assert_operator metrics["bodyScrollWidth"], :>, metrics["bodyClientWidth"] + 100
    assert_operator metrics["tableWidth"], :>, metrics["bodyClientWidth"] + 100
  end

  test "canvas and status details open separate overlays" do
    @task.update!(
      status: "drafting",
      draft_ros_json: {
        "draft_days" => [
          {
            "label" => "Wedding Day",
            "entries" => [
              { "time_label" => "4:00 PM", "title" => "Ceremony" }
            ]
          }
        ],
        "assumptions" => ["Use the ceremony as the anchor."],
        "review_flags" => ["Confirm vendor arrival."],
        "refinement_notes" => ["Planner requested shorter notes."]
      }
    )
    @task.append_event!(event_type: "drafted", message: "Agent produced draft.", created_by: users(:one))

    login_as_planner
    page.current_window.resize_to(1400, 900)
    visit event_ros_agent_task_path(@event, @task)

    click_button "Details"

    within ".ros-agent-canvas-details-dialog[open]" do
      assert_text "Canvas Details"
      assert_text "Use the ceremony as the anchor."
      assert_text "Draft JSON"
      assert_no_text "Task History"
    end

    within ".ros-agent-canvas-details-dialog[open]" do
      click_button "Close"
    end

    find(".ros-agent-status-trigger").click

    within ".ros-agent-task-details-dialog[open]" do
      assert_text "Task Details"
      assert_text "Task History"
      assert_text "Agent produced draft."
    end
  end
end
