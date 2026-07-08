require "test_helper"

module Events
  class RosAgentTasksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
      @other_event = events(:two)
      @user = users(:one)
      @task = agent_tasks(:draft_task)
      log_in_as(@user)
    end

    test "index lists event tasks newest first" do
      newer_task = AgentTask.create!(
        event: @event,
        created_by: @user,
        prompt: "Create the newest task."
      )

      get event_ros_agent_tasks_path(@event)

      assert_response :success
      assert_select "h1", text: "Agent Assist"
      assert_operator response.body.index(newer_task.prompt), :<, response.body.index(@task.prompt)
    end

    test "new shows prompt form and task-only source file upload for events with no documents" do
      event = events(:two)
      event.event_team_members.create!(
        user: @user,
        member_role: EventTeamMember::TEAM_ROLES[:planner]
      )

      get new_event_ros_agent_task_path(event)

      assert_response :success
      assert_select ".ros-agent-app.ros-agent-app--new", count: 1
      assert_select ".ros-agent-topbar h1", text: "Agent Assist"
      assert_select ".ros-agent-topbar a", text: "Back to ROS"
      assert_select ".ros-agent-topbar a", text: "Task List"
      assert_select ".ros-agent-prompt-strip", count: 1
      assert_select ".ros-agent-prompt-strip__attachments", count: 1
      assert_select ".ros-agent-prompt-strip__prompt", count: 1
      assert_select ".ros-agent-prompt-strip__settings", count: 1
      assert_select ".ros-agent-prompt-strip__attachments h2", text: "Attachments"
      assert_select ".ros-agent-prompt-strip__prompt h2", text: "Prompt"
      assert_select ".ros-agent-prompt-strip__settings h2", text: "Settings"
      assert_select ".ros-agent-prompt-strip .ros-agent-field-label", count: 0
      assert_select ".ros-agent-canvas[data-ros-agent-status-target='canvas']", count: 0
      assert_select ".ros-agent-canvas__header .ros-agent-canvas__label", count: 0
      assert_select ".ros-agent-bottom-rail[data-ros-agent-status-target='bottomRail']", count: 1
      assert_select ".ros-agent-bottom-rail__status p.sr-only[data-ros-agent-status-target='statusSummary']", count: 1
      assert_select "form[action='#{event_ros_agent_tasks_path(event)}'][enctype='multipart/form-data']" do
        assert_select "textarea[name='agent_task[prompt]']"
        assert_select "input[name='agent_task[mode]'][value='build_ros_from_source']", count: 1
        assert_select "select[name='agent_task[model]']" do
          assert_select "option[value='gpt-5.5']", text: "GPT-5.5"
          assert_select "option[value='gpt-5.4']", count: 0
          assert_select "option[value='gpt-5.4-mini']", text: "GPT-5.4 Mini"
        end
        assert_select "select[name='agent_task[reasoning_effort]']" do
          assert_select "option[value='none']", text: "None"
          assert_select "option[value='minimal']", text: "Minimal"
          assert_select "option[value='high']", text: "High"
          assert_select "option[value='xhigh']", text: "X-High"
        end
        assert_select "input[name='agent_task[source_files][]'][type='file'][multiple]", count: 1
        assert_select "input[name='agent_task[document_ids][]']", count: 0
        assert_select ".ros-agent-bottom-rail input[type='submit']", value: "Start Agent Assist"
      end
      assert_no_match "No uploaded documents are available for this event.", response.body
    end

    test "create uploads task-only source files, persists artifacts, and enqueues the runner" do
      fake_job_class = fake_run_task_job_class
      storage = FakeStorage.new
      enqueued = []

      fake_job_class.stub :perform_later, ->(task_id, mode:) { enqueued << { task_id:, mode: } } do
        with_temporary_run_task_job(fake_job_class) do
          R2::Storage.stub :new, storage do
            assert_difference("AgentTask.count", 1) do
              assert_difference("AgentTaskArtifact.count", 1) do
                assert_no_difference("Document.count") do
                  post event_ros_agent_tasks_path(@event), params: {
                    agent_task: {
                      prompt: "Adapt the uploaded schedule for this wedding.",
                      mode: "build_ros_from_source",
                      model: "gpt-5.4-mini",
                      reasoning_effort: "low",
                      source_files: [
                        fixture_file_upload("millar_sample.csv", "text/csv")
                      ]
                    }
                  }
                end
              end
            end
          end
        end
      end

      created_task = AgentTask.order(:created_at).last

      assert_redirected_to event_ros_agent_task_path(@event, created_task)
      assert_equal @user, created_task.created_by
      assert_equal "build_ros_from_source", created_task.mode
      assert_equal "gpt-5.4-mini", created_task.model
      assert_equal "low", created_task.reasoning_effort
      artifact = created_task.artifacts.order(:position).sole
      assert_nil artifact.document_id
      assert_equal "millar_sample.csv", artifact.filename
      assert_equal "text/csv", artifact.content_type
      assert_equal Digest::SHA256.hexdigest(file_fixture("millar_sample.csv").binread), artifact.checksum
      assert_match %r{\Aagent-tasks/#{created_task.id}/source-inputs/[0-9a-f-]+/millar_sample\.csv\z}, artifact.source_metadata_json["storage_uri"]
      assert_equal artifact.source_metadata_json["storage_uri"], storage.uploads.sole[:key]
      assert_equal "text/csv", storage.uploads.sole[:content_type]
      assert_includes storage.uploads.sole[:data], "Friday, June 13"
      assert_equal [{ task_id: created_task.id, mode: :initial_run }], enqueued
      assert_equal %w[source_file_uploaded task_created], created_task.events.order(:created_at).pluck(:event_type)
    end

    test "create requires at least one task source file" do
      assert_no_difference("AgentTask.count") do
        post event_ros_agent_tasks_path(@event), params: {
          agent_task: {
            prompt: "Just save this for later.",
            mode: "build_ros_from_source"
          }
        }
      end

      assert_response :unprocessable_content
      assert_includes response.body, "Upload at least one source file"
    end

    test "create succeeds without enqueueing when the runner job is unavailable" do
      storage = FakeStorage.new

      without_run_task_job do
        R2::Storage.stub :new, storage do
          assert_difference("AgentTask.count", 1) do
            post event_ros_agent_tasks_path(@event), params: {
              agent_task: {
                prompt: "Just save this for later.",
                mode: "build_ros_from_source",
                source_files: [
                  fixture_file_upload("millar_sample.csv", "text/csv")
                ]
              }
            }
          end
        end
      end

      created_task = AgentTask.order(:created_at).last

      assert_redirected_to event_ros_agent_task_path(@event, created_task)
      assert_equal "Agent task saved. Background runner is not available yet.", flash[:notice]
    end

    test "show renders task state, question batch, preview, and trace summary" do
      @task.update!(
        status: "ready_for_review",
        draft_ros_json: {
          "draft_days" => [
            {
              "label" => "Wedding Day",
              "entries" => [
                { "time_label" => "2:00 PM", "title" => "Ceremony", "notes" => "Draft note" }
              ]
            }
          ]
        },
        preview_json: {
          "create_count" => 1,
          "update_count" => 0,
          "delete_count" => 0,
          "tag_change_count" => 0,
          "time_change_count" => 1,
          "grouped_preview_rows" => {
            "creates" => [
              {
                "summary" => "Create ceremony.",
                "after" => { "title" => "Ceremony", "starts_at" => "2025-10-01T14:30:00Z", "duration_minutes" => 30 }
              }
            ],
            "updates" => [],
            "deletes" => []
          }
        },
        trace_summary_json: {
          "latest_run_label" => "Drafted plan",
          "tokens" => 3210
        }
      )

      get event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_select "h1", text: /Agent Assist/
      assert_select ".ros-agent-app.ros-agent-app--show", count: 1
      assert_select ".ros-agent-prompt-strip__prompt", text: /Adapt this prior event/
      assert_select ".ros-agent-canvas__body #review-plan", count: 1
      assert_select ".ros-agent-canvas__body #draft-ros", count: 0
      assert_select ".ros-agent-canvas__body #planning-questions", count: 0
      assert_select ".ros-agent-details-dialog", count: 2
      assert_select ".ros-agent-task-details-dialog[data-ros-agent-details-target='taskDialog']", count: 1
      assert_select ".ros-agent-task-details-dialog", text: /millar-run-of-show.pdf/
      assert_select ".ros-agent-task-details-dialog", text: /file_source_123/
      assert_select ".ros-agent-task-details-dialog", text: /Drafted plan/
      assert_select ".ros-agent-canvas-details-dialog[data-ros-agent-details-target='canvasDialog']", count: 1
      assert_select ".ros-agent-canvas-details-dialog", text: /Assumptions/
      assert_select ".ros-agent-canvas-details-dialog", text: /Plan JSON/
      assert_select ".ros-agent-canvas-details-dialog", text: /Task History/, count: 0
      assert_select ".ros-agent-canvas-details-dialog", text: /OpenAI Calls/, count: 0
      assert_select ".ros-agent-details-trigger[data-action='ros-agent-details#openCanvas']", text: "Details"
      assert_select ".ros-agent-status-trigger[data-action='ros-agent-details#openTask'][data-ros-agent-status-target='statusLabel']", count: 1
      assert_select "#review-plan table", text: /Oct 1/
      assert_select "#review-plan table", text: /2:30 PM/
      assert_no_match "2025-10-01T14:30:00Z", css_select("#review-plan").to_s
    end

    test "show renders live status controller for active tasks" do
      @task.update!(status: "drafting")

      get event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_select "[data-controller='ros-agent-status']", count: 1
      assert_select "[data-ros-agent-status-status-url-value='#{status_event_ros_agent_task_path(@event, @task)}']", count: 1
      assert_select "[data-ros-agent-status-initial-status-value='drafting']", count: 1
      assert_select "[data-ros-agent-status-target='statusLabel']", text: "Drafting"
      assert_select ".ros-agent-working", text: /working on it/
    end

    test "show anchors open planning questions so polling can reveal them" do
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

      get event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_select ".ros-agent-canvas__body section#planning-questions[tabindex='-1']", count: 1
      assert_select "section#planning-questions h2", text: "Planning Questions"
      assert_select ".ros-agent-question-grid .ros-agent-question-card", count: 1
      assert_select "form[action='#{answer_questions_event_ros_agent_task_path(@event, @task)}']", count: 1
      assert_select "input[type='radio'][name='answers[date_mapping]']", count: 2
      assert_select "input[type='radio'][name='answers[date_mapping]'][value='map_saturday']", count: 1
      assert_select "input[type='radio'][name='answers[date_mapping]'][value='__custom__']", count: 1
      assert_select "input[type='text'][name='custom_answers[date_mapping]'][data-action*='ros-agent-task#selectCustomAnswer']", count: 1
      assert_select "input[type='text'][name='freeform_answers[date_mapping]']", count: 0
      assert_select "input[type='text'][name='answers[date_mapping]']", count: 0
      assert_select "button", text: "Use recommended answers", count: 0
      assert_select ".ros-agent-bottom-rail input[type='submit'][form='ros-agent-question-form']", value: "Submit Answers"
    end

    test "show anchors draft ROS so polling can reveal it" do
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

      get event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_select ".ros-agent-canvas__body section#draft-ros[tabindex='-1']", count: 1
      assert_select "section#draft-ros h2", text: "Draft ROS", count: 0
      assert_select "section#draft-ros", text: /Draft agent output/, count: 0
      assert_select ".ros-agent-bottom-rail form[action='#{refine_draft_event_ros_agent_task_path(@event, @task)}']", count: 1
      assert_select ".ros-agent-bottom-rail form[action='#{request_final_plan_event_ros_agent_task_path(@event, @task)}']", count: 1
    end

    test "show formats draft ROS day groups and schedule times" do
      @event.run_of_show_calendar.update!(timezone: "America/New_York")
      @task.update!(
        status: "drafting",
        draft_ros_json: {
          "target_event_summary" => "A two-day adapted wedding ROS.",
          "date_mapping" => {
            "source_days" => [
              { "source_label" => "Friday source", "target_date" => "2027-10-15" }
            ]
          },
          "draft_days" => [
            {
              "label" => "Friday Pre-Event Production",
              "date" => "2027-10-15"
            },
            {
              "label" => "Saturday Main Event",
              "date" => "2027-10-16"
            }
          ],
          "draft_items" => [
            {
              "title" => "Production / Entertainment Crew Line Check",
              "timing" => {
                "kind" => "relative",
                "starts_at" => "2027-10-15T18:00:00-04:00",
                "relative_anchor_title" => "Guest Arrival",
                "relative_offset_minutes" => -120
              },
              "duration_minutes" => 120,
              "confidence" => "medium",
              "details" => [
                {
                  "field" => "time_caption",
                  "value" => "All day caption",
                  "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "time caption" }]
                },
                {
                  "field" => "notes",
                  "value" => "Confirm source-specific entertainment handoff.",
                  "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "notes column" }]
                },
                {
                  "field" => "vendor_handling",
                  "value" => "Coordinate production vendor arrival.",
                  "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "vendor column" }]
                },
                {
                  "field" => "tags",
                  "value" => "Production, Music",
                  "source_refs" => [{ "artifact" => "millar_sample.csv", "locator" => "tags inferred from section" }]
                }
              ],
              "custom_agent_field" => "do not hide me",
              "source_refs" => [
                { "artifact" => "millar_sample.csv", "locator" => "row 2" }
              ]
            }
          ],
          "assumptions" => ["Use Friday for production checks.", "Confirm the wedding day anchor."],
          "review_flags" => ["Confirm whether a production check is needed.", "Confirm source-only placeholders."],
          "refinement_notes" => ["Planner asked for a cleaner display."],
          "source_references" => [
            { "artifact" => "millar_sample.csv", "locator" => "Friday section" }
          ]
        }
      )

      get event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_select "#draft-ros > .ros-agent-draft__table", 1
      assert_select "#draft-ros [data-controller='ros-agent-draft-table']", 0
      assert_select "#draft-ros .ros-agent-draft__table-shell", 0
      assert_select "#draft-ros .ros-agent-draft__summary-table", 0
      assert_select "#draft-ros", text: /Target Event Summary/, count: 0
      assert_select "#draft-ros", text: /Draft agent output/, count: 0
      assert_select "#draft-ros button", text: "Previous fields", count: 0
      assert_select "#draft-ros button", text: "Next fields", count: 0
      assert_select "#draft-ros .event-calendars__date-label", text: "Friday, October 15"
      assert_select "#draft-ros .event-calendars__date-label", text: "Saturday, October 16", count: 0
      assert_select "#draft-ros .ros-agent-draft__table tbody tr.event-calendars__row", count: 1
      assert_no_match "Agent day label", response.body
      assert_select "#draft-ros", text: /Friday Pre-Event Production/, count: 0
      assert_select "#draft-ros td.event-calendars__schedule-column", text: "6:00 PM – 8:00 PM"
      assert_select "#draft-ros", text: /A two-day adapted wedding ROS/, count: 0
      assert_select "#draft-ros", text: /Friday source/, count: 0
      assert_select "#draft-ros", text: /Use Friday for production checks/, count: 0
      assert_select "#draft-ros", text: /Confirm whether a production check is needed/, count: 0
      assert_select "#draft-ros", text: /Planner asked for a cleaner display/, count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "notes"
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "vendor_handling"
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "tags"
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "timing", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "duration", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "duration_minutes", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "confidence", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "source_ref", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "source_refs", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "time_label", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "time_caption", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "details", count: 0
      assert_select "#draft-ros .ros-agent-draft__table thead th", text: "location", count: 0
      assert_select "#draft-ros", text: /millar_sample.csv/, count: 0
      assert_select "#draft-ros", text: /relative_anchor_title/, count: 0
      assert_select "#draft-ros", text: /2027-10-15T18:00:00-04:00/, count: 0
      assert_select "#draft-ros", text: /Guest Arrival/, count: 0
      assert_select "#draft-ros", text: /Confirm source-specific entertainment handoff/
      assert_select "#draft-ros", text: /Coordinate production vendor arrival/
      assert_select "#draft-ros", text: /Production/
      assert_select "#draft-ros", text: /Music/
      assert_select "#draft-ros", text: /medium/, count: 0
      assert_select "#draft-ros", text: /do not hide me/
    end

    test "show renders every draft item even when legacy draft days omit item dates" do
      @event.run_of_show_calendar.update!(timezone: "America/New_York")
      @task.update!(
        status: "drafting",
        draft_ros_json: {
          "target_event_summary" => "A production timeline with many dated rows.",
          "date_mapping" => { "source_days" => [] },
          "draft_days" => [
            { "label" => "Load-In Begins", "date" => "2027-09-18" },
            { "label" => "Event Day", "date" => "2027-10-14" }
          ],
          "draft_items" => [
            draft_item("Parking Lot Available for Staging", "2027-09-18T00:00:00-04:00", "row 2"),
            draft_item("Intermediate Production Build", "2027-09-19T08:00:00-04:00", "row 8"),
            draft_item("Final Prep Before Event", "2027-10-13T14:00:00-04:00", "row 125"),
            draft_item("Three Sprinter Vans", "2027-10-14T07:00:00-04:00", "row 151")
          ],
          "assumptions" => [],
          "review_flags" => [],
          "refinement_notes" => [],
          "source_references" => []
        }
      )

      get event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_select "#draft-ros .ros-agent-draft__table tbody tr.event-calendars__row", count: 4
      assert_select "#draft-ros", text: /Parking Lot Available for Staging/
      assert_select "#draft-ros", text: /Intermediate Production Build/
      assert_select "#draft-ros", text: /Final Prep Before Event/
      assert_select "#draft-ros", text: /Three Sprinter Vans/
      assert_select "#draft-ros .event-calendars__date-label", text: "Saturday, September 18"
      assert_select "#draft-ros .event-calendars__date-label", text: "Sunday, September 19"
      assert_select "#draft-ros .event-calendars__date-label", text: "Wednesday, October 13"
      assert_select "#draft-ros .event-calendars__date-label", text: "Thursday, October 14"
    end

    test "show anchors review plan so polling can reveal it" do
      @task.update!(
        status: "ready_for_review",
        plan_json: { "operations" => [{ "operation_id" => "create-1", "operation_type" => "create_item" }] },
        validation_json: { "blocking_errors" => [] },
        preview_json: {
          "summary" => "Create the wedding day ROS.",
          "operations" => [
            {
              "action" => "create",
              "title" => "Ceremony",
              "when" => "4:00 PM"
            }
          ]
        }
      )

      get event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_select ".ros-agent-canvas__body section#review-plan[tabindex='-1']", count: 1
      assert_select "section#review-plan h2", text: "Review Plan"
      assert_select "table", text: /Ceremony/
      approve_path = approve_event_ros_agent_task_path(@event, @task)
      assert_select "#review-plan form[action='#{approve_path}']", count: 0
      assert_select ".ros-agent-bottom-rail form[action='#{approve_path}']", count: 1
    end

    test "status marks completed draft as actionable for live polling" do
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

      get status_event_ros_agent_task_path(@event, @task)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal false, body["active"]
      assert_equal "Draft Ready", body["status_label"]
      assert_equal "draft", body["canvas_state"]
      assert_includes body["canvas_html"], "id=\"draft-ros\""
      assert_includes body["canvas_html"], "Ceremony"
      assert_includes body["bottom_rail_html"], "Confirm Draft"
      assert_includes body["metadata_html"], "Task History"
      assert_includes body["canvas_metadata_html"], "Draft JSON"
      assert_not_includes body["canvas_metadata_html"], "Task History"
    end

    test "status keeps polling during refinement even when an old draft exists" do
      @task.update!(
        status: "drafting",
        draft_ros_json: {
          "draft_days" => [
            {
              "label" => "Wedding Day",
              "entries" => [
                { "time_label" => "4:00 PM", "title" => "Old Ceremony Draft" }
              ]
            }
          ]
        }
      )
      @task.llm_calls.create!(
        purpose: "refinement",
        provider: "openai",
        model: "gpt-5.5",
        reasoning_effort: "high",
        status: "pending",
        attempt: 1,
        started_at: Time.current,
        request_json: {}
      )

      get status_event_ros_agent_task_path(@event, @task)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["active"]
      assert_equal "Drafting", body["status_label"]
      assert_equal "working", body["canvas_state"]
      assert_includes body["canvas_html"], "working on it"
      assert_not_includes body["canvas_html"], "Old Ceremony Draft"
    end

    test "status keeps draft canvas visible while final plan is being prepared" do
      @task.update!(
        status: "planning",
        draft_ros_json: {
          "draft_days" => [
            {
              "label" => "Wedding Day",
              "entries" => [
                { "time_label" => "4:00 PM", "title" => "Ceremony Draft" }
              ]
            }
          ]
        }
      )

      get status_event_ros_agent_task_path(@event, @task)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal true, body["active"]
      assert_equal "Planning", body["status_label"]
      assert_equal "draft", body["canvas_state"]
      assert_includes body["canvas_html"], "Ceremony Draft"
      assert_not_includes body["canvas_html"], "working on it"
    end

    test "status marks review plan as actionable for live polling" do
      @task.update!(
        status: "ready_for_review",
        plan_json: { "operations" => [{ "operation_id" => "create-1", "operation_type" => "create_item" }] },
        validation_json: { "blocking_errors" => [] },
        preview_json: {
          "summary" => "Create the wedding day ROS.",
          "operations" => [
            {
              "action" => "create",
              "title" => "Ceremony",
              "when" => "4:00 PM"
            }
          ]
        }
      )

      get status_event_ros_agent_task_path(@event, @task)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal false, body["active"]
      assert_equal "Ready For Review", body["status_label"]
      assert_equal "plan", body["canvas_state"]
      assert_includes body["canvas_html"], "id=\"review-plan\""
      assert_includes body["canvas_html"], "Ceremony"
      assert_includes body["bottom_rail_html"], "Approve Plan"
    end

    test "status keeps review warnings out of the plan bottom rail" do
      @task.update!(
        status: "ready_for_review",
        plan_json: { "operations" => [{ "operation_id" => "create-1", "operation_type" => "create_item" }] },
        validation_json: { "blocking_errors" => [], "warnings" => ["Confirm vendor arrival before apply."] },
        preview_json: {
          "summary" => "Create the wedding day ROS.",
          "operations" => [
            {
              "action" => "create",
              "title" => "Ceremony",
              "when" => "4:00 PM"
            }
          ]
        }
      )

      get status_event_ros_agent_task_path(@event, @task)

      assert_response :success
      body = JSON.parse(response.body)
      assert_not_includes body["bottom_rail_html"], "Confirm vendor arrival before apply."
      assert_includes body["bottom_rail_html"], "Approve Plan"
    end

    test "applied status bottom rail omits retained plan warnings" do
      @task.update!(
        status: "applied",
        plan_json: {
          "warnings" => ["If vendors are later linked, these blank assignments can be mapped categorically."],
          "operations" => [{ "operation_id" => "create-1", "operation_type" => "create_item" }]
        },
        preview_json: {
          "warnings" => ["If vendors are later linked, these blank assignments can be mapped categorically."],
          "grouped_preview_rows" => { "creates" => [], "updates" => [], "deletes" => [] }
        }
      )

      get status_event_ros_agent_task_path(@event, @task)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal "Applied", body["status_label"]
      assert_equal "plan", body["canvas_state"]
      assert_not_includes body["bottom_rail_html"], "If vendors are later linked"
      assert_not_includes body["bottom_rail_html"], "Apply Approved Plan"
      assert_not_includes body["bottom_rail_html"], "Approve Plan"
    end

    test "status renders planning questions for live polling" do
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

      get status_event_ros_agent_task_path(@event, @task)

      assert_response :success
      body = JSON.parse(response.body)
      assert_equal false, body["active"]
      assert_equal "questions", body["canvas_state"]
      assert_includes body["canvas_html"], "id=\"planning-questions\""
      assert_includes body["canvas_html"], "Date Mapping"
      assert_includes body["bottom_rail_html"], "Submit Answers"
    end

    test "status returns no-cache json with source files llm calls events and last error" do
      @task.update!(
        status: "planning",
        last_error_json: {
          "class" => "RuntimeError",
          "message" => "Planner failed to load the source outline."
        }
      )

      @task.llm_calls.create!(
        purpose: "final_plan",
        provider: "openai",
        model: "gpt-5.5",
        reasoning_effort: "high",
        status: "completed",
        attempt: 2,
        started_at: Time.zone.parse("2026-06-22 10:20:00"),
        completed_at: Time.zone.parse("2026-06-22 10:20:04"),
        duration_ms: 4000,
        usage_json: { "input_tokens" => 123, "output_tokens" => 45 },
        response_json: { "status" => "ok" }
      )

      @task.llm_calls.create!(
        purpose: "summary",
        provider: "openai",
        model: "gpt-5.5",
        reasoning_effort: "high",
        status: "failed",
        attempt: 3,
        started_at: Time.zone.parse("2026-06-22 10:25:00"),
        completed_at: Time.zone.parse("2026-06-22 10:25:02"),
        duration_ms: 2000,
        error_json: {
          "class" => "OpenAI::Error",
          "message" => "The model call timed out."
        }
      )

      @task.append_event!(
        event_type: "status_changed",
        message: "Task is now planning.",
        payload: { from: "drafting", to: "planning" },
        created_by: @user
      )

      get status_event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_includes response.headers["Cache-Control"], "no-store"
      assert_equal "no-cache", response.headers["Pragma"]

      payload = JSON.parse(response.body)
      assert_equal "planning", payload["status"]
      assert_equal true, payload["active"]
      assert_equal "Planning", payload["status_label"]
      assert_equal "Planner failed to load the source outline.", payload["last_error"]["message"]

      source_file = payload["source_files"].first
      assert_equal "millar-run-of-show.pdf", source_file["filename"]
      assert_equal 2048, source_file["size_bytes"]
      assert_equal "ready", source_file["openai_state"]

      llm_call_purposes = payload["llm_calls"].map { |call| call["purpose"] }
      assert_includes llm_call_purposes, "final_plan"
      assert_includes llm_call_purposes, "summary"
      assert_equal 4000, payload["llm_calls"].find { |call| call["purpose"] == "final_plan" }["duration_ms"]
      assert_equal({ "input_tokens" => 123, "output_tokens" => 45 }, payload["llm_calls"].find { |call| call["purpose"] == "final_plan" }["usage"])
      assert_equal "The model call timed out.", payload["llm_calls"].find { |call| call["purpose"] == "summary" }["error"]["message"]

      assert_includes payload["task_events"].map { |event| event["event_type"] }, "drafted"
      assert_includes payload["task_events"].map { |event| event["event_type"] }, "status_changed"
      assert_equal "status_changed", payload["task_events"].last["event_type"]
    end

    test "status refuses tasks from another event" do
      get status_event_ros_agent_task_path(@other_event, @task)

      assert_response :not_found
    end

    test "answer_questions updates the open batch, appends an event, and enqueues follow-up work" do
      batch = agent_task_question_batches(:open_questions)
      fake_job_class = fake_run_task_job_class
      enqueued = []

      fake_job_class.stub :perform_later, ->(task_id, mode:) { enqueued << { task_id:, mode: } } do
        with_temporary_run_task_job(fake_job_class) do
          post answer_questions_event_ros_agent_task_path(@event, @task), params: {
            answers: {
              date_mapping: "map_saturday_to_wedding_date",
              scrub_names: "__custom__"
            },
            custom_answers: {
              date_mapping: "This should be ignored unless custom is selected.",
              scrub_names: "Remove names but keep vendor roles."
            }
          }
        end
      end

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "answered", batch.reload.status
      assert_equal "map_saturday_to_wedding_date", batch.answers_json["date_mapping"]
      assert_equal "Remove names but keep vendor roles.", batch.answers_json["scrub_names"]
      assert_equal "analyzing", @task.reload.status
      assert_equal [{ task_id: @task.id, mode: :answer_questions }], enqueued
      assert_equal "questions_answered", @task.events.order(:created_at).last.event_type
    end

    test "answer_questions accepts legacy freeform answers as a fallback" do
      batch = agent_task_question_batches(:open_questions)

      without_run_task_job do
        post answer_questions_event_ros_agent_task_path(@event, @task), params: {
          answers: {
            date_mapping: "map_saturday_to_wedding_date"
          },
          freeform_answers: {
            scrub_names: "Legacy custom answer."
          }
        }
      end

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "answered", batch.reload.status
      assert_equal "map_saturday_to_wedding_date", batch.answers_json["date_mapping"]
      assert_equal "Legacy custom answer.", batch.answers_json["scrub_names"]
    end

    test "answer_questions rejects a selected custom answer without custom text" do
      batch = agent_task_question_batches(:open_questions)

      assert_no_difference("AgentTaskEvent.count") do
        post answer_questions_event_ros_agent_task_path(@event, @task), params: {
          answers: {
            date_mapping: "__custom__",
            scrub_names: "remove_source_names"
          },
          custom_answers: {
            date_mapping: "",
            scrub_names: ""
          }
        }
      end

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "open", batch.reload.status
      assert_equal({}, batch.answers_json)
      assert_equal "Add a custom answer or choose a listed option for Date Mapping.", flash[:alert]
    end

    test "refine_draft records refinement guidance and enqueues the refinement run" do
      fake_job_class = fake_run_task_job_class
      enqueued = []

      fake_job_class.stub :perform_later, ->(task_id, mode:) { enqueued << { task_id:, mode: } } do
        with_temporary_run_task_job(fake_job_class) do
          post refine_draft_event_ros_agent_task_path(@event, @task), params: {
            refinement_prompt: "Keep the ceremony vendor placeholders generic."
          }
        end
      end

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal [{ task_id: @task.id, mode: :refine_draft }], enqueued
      task_event = @task.events.order(:created_at).last
      assert_equal "draft_refinement_requested", task_event.event_type
      assert_equal "Keep the ceremony vendor placeholders generic.", task_event.payload_json["refinement_prompt"]
    end

    test "request_final_plan refuses when there is no draft" do
      post request_final_plan_event_ros_agent_task_path(@event, @task)

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "Create a draft ROS before requesting a final plan.", flash[:alert]
    end

    test "request_final_plan enqueues planning when a draft exists" do
      @task.update!(draft_ros_json: { "draft_days" => [{ "label" => "Wedding Day" }] })
      fake_job_class = fake_run_task_job_class
      enqueued = []

      fake_job_class.stub :perform_later, ->(task_id, mode:) { enqueued << { task_id:, mode: } } do
        with_temporary_run_task_job(fake_job_class) do
          post request_final_plan_event_ros_agent_task_path(@event, @task)
        end
      end

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal [{ task_id: @task.id, mode: :request_final_plan }], enqueued
      assert_equal "final_plan_requested", @task.events.order(:created_at).last.event_type
    end

    test "approve records planner approval on the current plan version" do
      @task.update!(
        status: "ready_for_review",
        current_plan_version: 4,
        plan_json: { "operations" => [] },
        validation_json: { "blocking_errors" => [] }
      )

      post approve_event_ros_agent_task_path(@event, @task)

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      @task.reload
      assert_equal "approved", @task.status
      assert_equal @user, @task.approved_by
      assert_equal 4, @task.approved_plan_version
      assert_not_nil @task.approved_at
    end

    test "approve refuses plans with blocking validation errors" do
      @task.update!(
        status: "ready_for_review",
        current_plan_version: 4,
        plan_json: { "operations" => [] },
        validation_json: { "blocking_errors" => ["Operation op_1 targets another calendar."] }
      )

      post approve_event_ros_agent_task_path(@event, @task)

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "ready_for_review", @task.reload.status
      assert_nil @task.approved_at
      assert_equal "Resolve blocking validation errors before approval.", flash[:alert]
    end

    test "approve requires server-side acknowledgement for high-risk operations" do
      @task.update!(
        status: "ready_for_review",
        current_plan_version: 4,
        plan_json: { "operations" => [] },
        validation_json: { "blocking_errors" => [] },
        preview_json: { "high_risk_operation_ids" => ["delete_1"] }
      )

      post approve_event_ros_agent_task_path(@event, @task)

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "ready_for_review", @task.reload.status
      assert_equal "Acknowledge high-risk operations before continuing.", flash[:alert]
    end

    test "approve records high-risk acknowledgement when checked" do
      @task.update!(
        status: "ready_for_review",
        current_plan_version: 4,
        plan_json: { "operations" => [] },
        validation_json: { "blocking_errors" => [] },
        preview_json: { "high_risk_operation_ids" => ["delete_1"] }
      )

      post approve_event_ros_agent_task_path(@event, @task), params: { high_risk_acknowledgement: "1" }

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      @task.reload
      assert_equal "approved", @task.status
      assert_equal true, @task.validation_json.dig("approval", "high_risk_acknowledged")
      assert_equal ["delete_1"], @task.validation_json.dig("approval", "high_risk_operation_ids")
    end

    test "apply requires approval state and high-risk acknowledgement before delegating" do
      @task.update!(
        status: "approved",
        current_plan_version: 2,
        approved_plan_version: 2,
        plan_json: {
          "operations" => [
            { "operation_id" => "delete_1", "operation_type" => "delete_item", "risk_level" => "high" }
          ]
        },
        validation_json: { "blocking_errors" => [] },
        preview_json: { "high_risk_operation_ids" => ["delete_1"] }
      )

      post apply_event_ros_agent_task_path(@event, @task)

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "Acknowledge high-risk operations before continuing.", flash[:alert]
    end

    test "apply delegates to the change plan applier when available" do
      @task.update!(
        status: "approved",
        current_plan_version: 2,
        approved_plan_version: 2,
        plan_json: {
          "operations" => [
            { "operation_id" => "create-1", "operation_type" => "create_item" }
          ]
        }
      )

      fake_result = Struct.new(:applied?, :errors, :operation_counts).new(
        true,
        [],
        { create_count: 1, update_count: 0, delete_count: 0, create_tag_count: 0, assign_tag_count: 0 }
      )
      fake_applier = Minitest::Mock.new
      fake_applier.expect(:call, fake_result)

      RosAgent::ChangePlanApplier.stub :new, ->(task:, calendar:, plan_hash:) {
        assert_equal @task, task
        assert_equal @event.run_of_show_calendar, calendar
        assert_equal @task.plan_json, plan_hash
        fake_applier
      } do
        post apply_event_ros_agent_task_path(@event, @task)
      end

      fake_applier.verify
      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "Applied ROS agent plan.", flash[:notice]
    end

    private

    def draft_item(title, starts_at, source_row)
      {
        "title" => title,
        "timing" => {
          "kind" => "fixed",
          "starts_at" => starts_at,
          "relative_anchor_title" => nil,
          "relative_offset_minutes" => nil
        },
        "duration_minutes" => 60,
        "confidence" => "high",
        "source_refs" => [
          { "artifact" => "production_timeline.csv", "locator" => source_row }
        ],
        "details" => []
      }
    end

    class FakeStorage
      attr_reader :uploads

      def initialize
        @uploads = []
      end

      def upload_io(key, io, content_type:)
        uploads << {
          key: key,
          data: io.read,
          content_type: content_type
        }
      end
    end

    def fake_run_task_job_class
      Class.new do
        def self.perform_later(_task_id, mode:); end
      end
    end

    def with_temporary_run_task_job(fake_job_class)
      original_job = RosAgent.send(:remove_const, :RunTaskJob) if defined?(RosAgent::RunTaskJob)
      RosAgent.const_set(:RunTaskJob, fake_job_class)
      yield
    ensure
      RosAgent.send(:remove_const, :RunTaskJob) if defined?(RosAgent::RunTaskJob)
      RosAgent.const_set(:RunTaskJob, original_job) if original_job
    end

    def without_run_task_job
      original_job = RosAgent.send(:remove_const, :RunTaskJob) if defined?(RosAgent::RunTaskJob)
      yield
    ensure
      RosAgent.const_set(:RunTaskJob, original_job) if original_job
    end
  end
end
