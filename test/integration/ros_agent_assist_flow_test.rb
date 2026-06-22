require "test_helper"

class RosAgentAssistFlowTest < ActionDispatch::IntegrationTest
  class SequenceClient
    def initialize(responses)
      @responses = responses
    end

    def responses_create(**)
      @responses.shift || raise("No stubbed response remaining")
    end
  end

  class NoopUploader
    def initialize(**); end

    def call; end
  end

  test "stubbed agent flow does not write ROS items until approval and apply" do
    event = events(:one)
    user = users(:one)
    calendar = event.run_of_show_calendar || event.event_calendars.create!(
      name: "Run of Show",
      timezone: EventCalendar::DEFAULT_TIMEZONE,
      kind: EventCalendar::KINDS[:master]
    )
    task = AgentTask.create!(
      event: event,
      created_by: user,
      prompt: "Adapt the attached previous wedding ROS into this existing event."
    )
    task.artifacts.create!(
      document: documents(:contract_v1),
      document_logical_id: documents(:contract_v1).logical_id,
      filename: "prior-wedding-ros.csv",
      content_type: "text/csv",
      size_bytes: 512,
      checksum: "flow-source-checksum",
      openai_file_id: "file_prior_ros",
      source_kind: AgentTaskArtifact::SOURCE_KINDS[:source_document],
      position: 1
    )
    client = SequenceClient.new(
      [
        response_hash(source_understood_payload),
        response_hash(question_payload),
        response_hash(draft_payload),
        response_hash(change_plan_payload)
      ]
    )

    assert_no_difference -> { calendar.calendar_items.count } do
      run_agent(task, client, :initial_run)
      assert_equal "needs_input", task.reload.status

      batch = task.question_batches.open.last
      assert_equal "date_mapping", batch.questions_json.first["key"]

      batch.answer!({ "date_mapping" => "map_source_wedding_day_to_event_date" })
      run_agent(task, client, :refine_draft)
      assert_equal "drafting", task.reload.status
      assert_equal "Wedding Day", task.draft_ros_json.dig("draft_days", 0, "label")

      run_agent(task, client, :request_final_plan)
      assert_equal "ready_for_review", task.reload.status
      assert_equal 1, task.preview_json["create_count"] || task.preview_json[:create_count]
      assert_empty task.validation_json["blocking_errors"] || task.validation_json[:blocking_errors]

      task.update!(
        status: AgentTask::STATUSES[:approved],
        approved_by: user,
        approved_at: Time.current,
        approved_plan_version: task.current_plan_version
      )
    end

    assert_difference -> { calendar.calendar_items.reload.count }, 1 do
      result = RosAgent::ChangePlanApplier.new(task: task.reload, calendar: calendar, plan_hash: task.plan_json).call
      assert result.applied?, result.errors.to_sentence
    end

    created_item = calendar.calendar_items.order(:created_at).last
    assert_equal "Crew Call", created_item.title
    assert_equal "applied", task.reload.status
  end

  test "final plan review does not create a run of show calendar before approval" do
    event = events(:two)
    task = AgentTask.create!(
      event: event,
      created_by: users(:one),
      prompt: "Create a first draft ROS inside this existing event."
    )
    client = SequenceClient.new([response_hash(change_plan_payload)])

    assert_nil event.run_of_show_calendar
    assert_no_difference -> { EventCalendar.count } do
      run_agent(task, client, :request_final_plan)
    end

    assert_equal "ready_for_review", task.reload.status
    assert_nil event.reload.run_of_show_calendar
  end

  private

  def run_agent(task, client, mode)
    RosAgent::Runner.new(
      task: task,
      client: client,
      source_document_uploader_class: NoopUploader
    ).call(mode: mode)
  end

  def response_hash(payload)
    payload = agent_turn_payload(payload) if %w[source_understood needs_input draft_ready].include?(payload["state"])

    {
      "id" => "resp_#{payload.fetch("state")}",
      "usage" => { "input_tokens" => 10, "output_tokens" => 20 },
      "output" => [
        {
          "content" => [
            {
              "type" => "output_text",
              "parsed" => payload
            }
          ]
        }
      ]
    }
  end

  def agent_turn_payload(payload)
    {
      "source_understanding" => nil,
      "recommended_next_state" => nil,
      "questions" => [],
      "draft_ros" => nil,
      "assumptions" => [],
      "source_observations" => [],
      "risk_notes" => [],
      "review_notes" => [],
      "suggested_next_questions" => []
    }.merge(payload)
  end

  def source_understood_payload
    {
      "state" => "source_understood",
      "summary" => "Understood prior wedding ROS.",
      "source_understanding" => {
        "source_title" => "prior-wedding-ros.csv",
        "source_kind" => "prior_event_ros",
        "overall_read" => "A wedding day ROS with production setup and ceremony anchors.",
        "inferred_days" => [
          {
            "source_label" => "Saturday",
            "role" => "wedding_day",
            "confidence" => "high",
            "notes" => "Primary event day."
          }
        ],
        "reusable_patterns" => ["Crew call before ceremony"],
        "source_specific_details" => [
          {
            "detail" => "Prior couple names",
            "recommended_action" => "remove_or_replace",
            "reason" => "Specific to the source wedding."
          }
        ],
        "uncertainties" => [],
        "confidence_notes" => [],
        "source_evidence_refs" => [{ "artifact" => "prior-wedding-ros.csv", "locator" => "rows 1-3" }]
      },
      "recommended_next_state" => "needs_input",
      "risk_notes" => []
    }
  end

  def question_payload
    {
      "state" => "needs_input",
      "summary" => "Confirm date mapping.",
      "questions" => [
        {
          "key" => "date_mapping",
          "label" => "Date Mapping",
          "question" => "Should Saturday become the event date?",
          "why_it_matters" => "Every absolute time shifts from this anchor.",
          "required" => true,
          "answer_type" => "single_choice",
          "options" => [
            {
              "value" => "map_source_wedding_day_to_event_date",
              "label" => "Map to event date",
              "recommended" => true,
              "description" => "Use the existing event date as the wedding day."
            }
          ],
          "freeform_allowed" => true
        }
      ],
      "assumptions" => [],
      "source_observations" => [],
      "risk_notes" => []
    }
  end

  def draft_payload
    {
      "state" => "draft_ready",
      "summary" => "Draft ROS ready.",
      "draft_ros" => {
        "target_event_summary" => "Existing wedding event.",
        "date_mapping" => {
          "source_days" => [
            { "source_label" => "Saturday", "target_date" => "2026-08-15" }
          ]
        },
        "draft_days" => [{ "label" => "Wedding Day", "date" => "2026-08-15" }],
        "draft_items" => [
          {
            "title" => "Crew Call",
            "day_label" => "Wedding Day",
            "timing" => { "kind" => "absolute", "starts_at" => "2026-08-15T14:00:00Z" },
            "duration_minutes" => 60,
            "notes" => "Production setup.",
            "location" => "Main Venue",
            "vendor_handling" => "placeholder",
            "staff_handling" => "map_to_event_team",
            "tags" => ["Production"],
            "confidence" => "high",
            "planner_review_needed" => false,
            "source_refs" => [{ "artifact" => "prior-wedding-ros.csv", "locator" => "row 2" }]
          }
        ],
        "assumptions" => [],
        "review_flags" => [],
        "refinement_notes" => [],
        "source_references" => [{ "artifact" => "prior-wedding-ros.csv", "locator" => "row 2" }]
      },
      "assumptions" => [],
      "review_notes" => [],
      "suggested_next_questions" => []
    }
  end

  def change_plan_payload
    {
      "state" => "ready_for_review",
      "summary" => "Create the adapted wedding day ROS.",
      "assumptions" => [],
      "operations" => [
        {
          "operation_id" => "create_crew_call",
          "operation_type" => "create_item",
          "summary" => "Create crew call.",
          "risk_level" => "low",
          "source_refs" => [{ "artifact" => "prior-wedding-ros.csv", "locator" => "row 2" }],
          "item_attributes" => {
            "title" => "Crew Call",
            "starts_at" => "2026-08-15T14:00:00Z",
            "duration_minutes" => 60,
            "notes" => "Production setup.",
            "location_name" => "Main Venue"
          },
          "reasoning_summary" => "Preserves reusable production setup timing."
        }
      ],
      "warnings" => [],
      "review_highlights" => []
    }
  end
end
