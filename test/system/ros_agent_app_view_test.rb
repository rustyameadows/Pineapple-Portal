require "application_system_test_case"

class RosAgentAppViewTest < ApplicationSystemTestCase
  setup do
    @event = events(:one)
    @task = agent_tasks(:draft_task)
  end

  test "new agent assist centers the prompt strip without a setup canvas" do
    login_as_planner
    page.current_window.resize_to(1400, 900)
    visit new_event_ros_agent_task_path(@event)

    assert_selector ".ros-agent-app.ros-agent-app--new"
    assert_selector ".ros-agent-prompt-strip"
    assert_no_selector ".ros-agent-canvas"

    metrics = page.evaluate_script(<<~JS)
      (() => {
        const app = document.querySelector(".ros-agent-app")
        const prompt = document.querySelector(".ros-agent-prompt-strip")
        const bottom = document.querySelector(".ros-agent-bottom-rail")
        const promptRect = prompt.getBoundingClientRect()
        const bottomRect = bottom.getBoundingClientRect()

        return {
          appHeight: app.getBoundingClientRect().height,
          bottomBottom: bottomRect.bottom,
          documentScrollable: document.documentElement.scrollHeight > window.innerHeight + 2,
          promptCenterY: promptRect.top + (promptRect.height / 2),
          promptHeight: promptRect.height,
          viewportCenterY: window.innerHeight / 2,
          viewportHeight: window.innerHeight
        }
      })()
    JS

    assert_equal false, metrics["documentScrollable"]
    assert_in_delta metrics["viewportHeight"], metrics["appHeight"], 4
    assert_in_delta metrics["viewportHeight"] * 0.15, metrics["promptHeight"], 16
    assert_in_delta metrics["viewportCenterY"], metrics["promptCenterY"], 80
    assert_in_delta metrics["viewportHeight"], metrics["bottomBottom"], 24
  end

  test "show model settings are two up while new settings stay stacked" do
    login_as_planner
    page.current_window.resize_to(1400, 900)

    visit event_ros_agent_task_path(@event, @task)
    show_metrics = page.evaluate_script(<<~JS)
      (() => {
        const items = Array.from(document.querySelectorAll(".ros-agent-settings-list > div"))
        const [model, reasoning] = items.map((item) => item.getBoundingClientRect())

        return {
          itemCount: items.length,
          modelLeft: Math.round(model.left),
          modelTop: Math.round(model.top),
          reasoningLeft: Math.round(reasoning.left),
          reasoningTop: Math.round(reasoning.top)
        }
      })()
    JS

    assert_equal 2, show_metrics["itemCount"]
    assert_in_delta show_metrics["modelTop"], show_metrics["reasoningTop"], 2
    assert_operator show_metrics["reasoningLeft"], :>, show_metrics["modelLeft"] + 20

    visit new_event_ros_agent_task_path(@event)
    new_metrics = page.evaluate_script(<<~JS)
      (() => {
        const items = Array.from(document.querySelectorAll(".ros-agent-settings-grid > .event-form__group"))
        const [model, reasoning] = items.map((item) => item.getBoundingClientRect())

        return {
          itemCount: items.length,
          modelLeft: Math.round(model.left),
          modelTop: Math.round(model.top),
          reasoningLeft: Math.round(reasoning.left),
          reasoningTop: Math.round(reasoning.top)
        }
      })()
    JS

    assert_equal 2, new_metrics["itemCount"]
    assert_in_delta new_metrics["modelLeft"], new_metrics["reasoningLeft"], 2
    assert_operator new_metrics["reasoningTop"], :>, new_metrics["modelTop"] + 12
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
          tableWidth: table.getBoundingClientRect().width,
          titleWidth: Array.from(table.querySelectorAll("thead th")).find((cell) => cell.textContent.trim() === "title").getBoundingClientRect().width,
          notesWidth: Array.from(table.querySelectorAll("thead th")).find((cell) => cell.textContent.trim() === "notes").getBoundingClientRect().width
        }
      })()
    JS

    assert_equal 0, metrics["innerShellCount"]
    assert_operator metrics["bodyScrollWidth"], :>, metrics["bodyClientWidth"] + 100
    assert_operator metrics["tableWidth"], :>, metrics["bodyClientWidth"] + 100
    assert_operator metrics["titleWidth"], :>, metrics["notesWidth"]
  end

  test "draft table fills the canvas when visible columns fit" do
    @task.update!(
      status: "drafting",
      draft_ros_json: {
        "draft_days" => [
          {
            "label" => "Production Day",
            "entries" => [
              {
                "time_label" => "All day",
                "title" => "George Mason University Parking Lot Available for Skyline Staging",
                "vendor_handling" => "Skyline Tent Co.",
                "tags" => ["Production"]
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
        const headers = Array.from(table.querySelectorAll("thead th"))
        const bodyStyles = getComputedStyle(body)
        const bodyContentWidth = body.clientWidth - parseFloat(bodyStyles.paddingLeft) - parseFloat(bodyStyles.paddingRight)
        return {
          bodyClientWidth: body.clientWidth,
          bodyContentWidth,
          bodyScrollWidth: body.scrollWidth,
          tableWidth: table.getBoundingClientRect().width,
          titleWidth: headers.find((cell) => cell.textContent.trim() === "title").getBoundingClientRect().width,
          vendorWidth: headers.find((cell) => cell.textContent.trim() === "vendor_handling").getBoundingClientRect().width,
          scheduleHeaderPosition: getComputedStyle(headers.find((cell) => cell.textContent.trim() === "Schedule")).position,
          titleHeaderPosition: getComputedStyle(headers.find((cell) => cell.textContent.trim() === "title")).position
        }
      })()
    JS

    assert_in_delta metrics["bodyContentWidth"], metrics["tableWidth"], 4
    assert_in_delta metrics["bodyClientWidth"], metrics["bodyScrollWidth"], 4
    assert_operator metrics["titleWidth"], :>, metrics["vendorWidth"]
    assert_equal "static", metrics["scheduleHeaderPosition"]
    assert_equal "static", metrics["titleHeaderPosition"]
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

    alignment = page.evaluate_script(<<~JS)
      getComputedStyle(document.querySelector(".ros-agent-task-details-dialog[open] .ros-agent-details__section")).alignContent
    JS
    assert_equal "start", alignment
  end
end
