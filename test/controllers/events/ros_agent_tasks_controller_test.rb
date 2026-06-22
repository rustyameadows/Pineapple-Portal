require "test_helper"

module Events
  class RosAgentTasksControllerTest < ActionDispatch::IntegrationTest
    setup do
      @event = events(:one)
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

    test "new shows prompt form and existing event documents" do
      get new_event_ros_agent_task_path(@event)

      assert_response :success
      assert_select "form[action='#{event_ros_agent_tasks_path(@event)}']" do
        assert_select "textarea[name='agent_task[prompt]']"
        assert_select "input[name='agent_task[mode]'][value='build_ros_from_source']", count: 1
        assert_select "input[name='agent_task[document_ids][]'][type='checkbox']", minimum: 1
      end
      assert_select "label", text: /Production Contract/
    end

    test "create persists the task, selected document artifacts, and enqueues the runner when available" do
      fake_job_class = fake_run_task_job_class
      enqueued = []

      fake_job_class.stub :perform_later, ->(task_id, mode:) { enqueued << { task_id:, mode: } } do
        with_temporary_run_task_job(fake_job_class) do
          assert_difference("AgentTask.count", 1) do
            assert_difference("AgentTaskArtifact.count", 2) do
              post event_ros_agent_tasks_path(@event), params: {
                agent_task: {
                  prompt: "Adapt the uploaded schedule for this wedding.",
                  mode: "build_ros_from_source",
                  document_ids: [documents(:contract_v1).id, documents(:packet_brief).id]
                }
              }
            end
          end
        end
      end

      created_task = AgentTask.order(:created_at).last

      assert_redirected_to event_ros_agent_task_path(@event, created_task)
      assert_equal @user, created_task.created_by
      assert_equal "build_ros_from_source", created_task.mode
      assert_equal [documents(:contract_v1).id, documents(:packet_brief).id].sort, created_task.artifacts.order(:position).pluck(:document_id).sort
      assert_equal [{ task_id: created_task.id, mode: :initial_run }], enqueued
      assert_equal "task_created", created_task.events.order(:created_at).last.event_type
    end

    test "create succeeds without enqueueing when the runner job is unavailable" do
      without_run_task_job do
        assert_difference("AgentTask.count", 1) do
          post event_ros_agent_tasks_path(@event), params: {
            agent_task: {
              prompt: "Just save this for later.",
              mode: "build_ros_from_source"
            }
          }
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
          "summary" => { "create_count" => 1 },
          "operations" => [
            { "action" => "create", "title" => "Ceremony", "when" => "2:00 PM" }
          ]
        },
        trace_summary_json: {
          "latest_run_label" => "Drafted plan",
          "tokens" => 3210
        }
      )

      get event_ros_agent_task_path(@event, @task)

      assert_response :success
      assert_select "h1", text: /Agent Assist/
      assert_select "section", text: /A few planning decisions will materially change/
      assert_select "table", text: /Ceremony/
      assert_select "section", text: /Drafted plan/
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
              scrub_names: "remove_source_names"
            }
          }
        end
      end

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      assert_equal "answered", batch.reload.status
      assert_equal "map_saturday_to_wedding_date", batch.answers_json["date_mapping"]
      assert_equal [{ task_id: @task.id, mode: :initial_run }], enqueued
      assert_equal "questions_answered", @task.events.order(:created_at).last.event_type
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
      @task.update!(status: "ready_for_review", current_plan_version: 4)

      post approve_event_ros_agent_task_path(@event, @task)

      assert_redirected_to event_ros_agent_task_path(@event, @task)
      @task.reload
      assert_equal "approved", @task.status
      assert_equal @user, @task.approved_by
      assert_equal 4, @task.approved_plan_version
      assert_not_nil @task.approved_at
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

    def fake_run_task_job_class
      Class.new do
        def self.perform_later(_task_id, mode:); end
      end
    end

    def with_temporary_run_task_job(fake_job_class)
      if defined?(RosAgent::RunTaskJob)
        RosAgent.send(:remove_const, :RunTaskJob)
      end
      RosAgent.const_set(:RunTaskJob, fake_job_class)
      yield
    ensure
      RosAgent.send(:remove_const, :RunTaskJob) if defined?(RosAgent::RunTaskJob)
    end

    def without_run_task_job
      original_job = RosAgent.send(:remove_const, :RunTaskJob) if defined?(RosAgent::RunTaskJob)
      yield
    ensure
      RosAgent.const_set(:RunTaskJob, original_job) if original_job
    end
  end
end
