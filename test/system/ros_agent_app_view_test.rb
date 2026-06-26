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
end
