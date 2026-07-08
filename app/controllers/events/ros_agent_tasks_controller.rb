module Events
  class RosAgentTasksController < ApplicationController
    CUSTOM_ANSWER_VALUE = RosAgentTasksHelper::CUSTOM_ANSWER_VALUE

    before_action :set_event
    before_action :set_task, only: %i[show status answer_questions refine_draft request_final_plan approve apply]

    def index
      @tasks = @event.agent_tasks.includes(:created_by).order(created_at: :desc, id: :desc)
    end

    def new
      @task = @event.agent_tasks.new(mode: AgentTask::MODES[:build_ros_from_source])
    end

    def create
      @task = @event.agent_tasks.new(task_params)
      @task.created_by = current_user
      source_files = task_source_files

      if source_files.empty?
        @task.errors.add(:base, "Upload at least one source file.")
        flash.now[:alert] = @task.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
        return
      end

      if @task.save
        attach_source_files!(source_files)
        @task.append_event!(event_type: "task_created", message: "Agent task created.", created_by: current_user)
        if enqueue_runner(:initial_run)
          redirect_to event_ros_agent_task_path(@event, @task), notice: "Agent task started."
        else
          redirect_to event_ros_agent_task_path(@event, @task), notice: "Agent task saved. Background runner is not available yet."
        end
      else
        flash.now[:alert] = @task.errors.full_messages.to_sentence
        render :new, status: :unprocessable_content
      end
    rescue StandardError => e
      @task.destroy if @task&.persisted?
      @task = @event.agent_tasks.new(task_params)
      @task.created_by = current_user
      @task.errors.add(:base, "Could not upload source files: #{e.message}")
      flash.now[:alert] = @task.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end

    def show
      @open_question_batch = open_question_batch_for(@task)
      @task_events = @task.events.includes(:created_by).order(created_at: :asc, id: :asc)
      @artifacts = @task.artifacts.order(:position)
      @status_snapshot = task_status_snapshot
    end

    def status
      disable_response_cache!
      render json: task_status_snapshot
    end

    def answer_questions
      batch = @task.question_batches.open.order(:position).last
      unless batch
        redirect_to event_ros_agent_task_path(@event, @task), alert: "There are no open questions to answer."
        return
      end

      blank_custom_answer_labels = blank_custom_answer_labels_for(batch)
      if blank_custom_answer_labels.any?
        redirect_to event_ros_agent_task_path(@event, @task),
                    alert: "Add a custom answer or choose a listed option for #{blank_custom_answer_labels.to_sentence}."
        return
      end

      submitted_answers = answers_params
      batch.answer!(submitted_answers)
      @task.update!(status: AgentTask::STATUSES[:analyzing])
      @task.append_event!(
        event_type: "questions_answered",
        message: "Planner answered agent questions.",
        payload: { answers: submitted_answers },
        created_by: current_user
      )
      enqueue_runner(:answer_questions)
      redirect_to event_ros_agent_task_path(@event, @task), notice: "Answers submitted."
    end

    def refine_draft
      refinement_prompt = params[:refinement_prompt].to_s.strip
      @task.append_event!(
        event_type: "draft_refinement_requested",
        message: "Planner requested draft refinement.",
        payload: { refinement_prompt: refinement_prompt },
        created_by: current_user
      )
      @task.update!(status: AgentTask::STATUSES[:drafting])
      enqueue_runner(:refine_draft)
      redirect_to event_ros_agent_task_path(@event, @task), notice: "Draft refinement requested."
    end

    def request_final_plan
      if @task.draft_ros_json.blank?
        redirect_to event_ros_agent_task_path(@event, @task), alert: "Create a draft ROS before requesting a final plan."
        return
      end

      @task.append_event!(
        event_type: "final_plan_requested",
        message: "Planner requested final ROS plan.",
        created_by: current_user
      )
      @task.update!(status: AgentTask::STATUSES[:planning])
      enqueue_runner(:request_final_plan)
      redirect_to event_ros_agent_task_path(@event, @task), notice: "Final plan requested."
    end

    def approve
      unless @task.approvable?
        redirect_to event_ros_agent_task_path(@event, @task), alert: "Resolve blocking validation errors before approval."
        return
      end
      return unless require_high_risk_acknowledgement!

      @task.update!(
        status: AgentTask::STATUSES[:approved],
        approved_by: current_user,
        approved_at: Time.current,
        approved_plan_version: @task.current_plan_version
      )
      @task.append_event!(
        event_type: "approved",
        message: "Planner approved plan.",
        payload: {
          high_risk_acknowledged: @task.high_risk_acknowledged?,
          high_risk_operation_ids: @task.high_risk_operation_ids
        },
        created_by: current_user
      )
      redirect_to event_ros_agent_task_path(@event, @task), notice: "Agent plan approved."
    end

    def apply
      unless defined?(RosAgent::ChangePlanApplier)
        redirect_to event_ros_agent_task_path(@event, @task), alert: "ROS plan applier is not available yet."
        return
      end
      return unless require_high_risk_acknowledgement!
      unless @task.ready_to_apply?
        redirect_to event_ros_agent_task_path(@event, @task), alert: "Approve the current validated plan before applying."
        return
      end

      result = RosAgent::ChangePlanApplier.new(
        task: @task,
        calendar: run_of_show_calendar,
        plan_hash: @task.plan_json
      ).call

      if result.applied?
        redirect_to event_ros_agent_task_path(@event, @task), notice: "Applied ROS agent plan."
      else
        redirect_to event_ros_agent_task_path(@event, @task), alert: result.errors.to_sentence
      end
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end

    def set_task
      @task = @event.agent_tasks.find(params[:id])
    end

    def task_params
      params.require(:agent_task).permit(:prompt, :mode, :model, :reasoning_effort)
    end

    def answers_params
      selected_answers = params.fetch(:answers, {}).permit!.to_h
      custom_answers = params.fetch(:custom_answers, {}).permit!.to_h.compact_blank
      legacy_freeform_answers = params.fetch(:freeform_answers, {}).permit!.to_h.compact_blank

      normalized_answers = selected_answers.to_h do |key, value|
        answer_value = value == CUSTOM_ANSWER_VALUE ? custom_answers[key].presence : value
        [key, answer_value]
      end.compact_blank

      normalized_answers.merge(legacy_freeform_answers)
    end

    def blank_custom_answer_labels_for(batch)
      selected_answers = params.fetch(:answers, {}).permit!.to_h
      custom_answers = params.fetch(:custom_answers, {}).permit!.to_h
      question_labels = batch.questions_json.index_by { |question| question["key"].to_s }.transform_values { |question| question["label"].presence || question["key"].to_s.humanize }

      selected_answers.filter_map do |key, value|
        next unless value == CUSTOM_ANSWER_VALUE
        next if custom_answers[key].to_s.strip.present?

        question_labels[key] || key.to_s.humanize
      end
    end

    def task_source_files
      Array(params.dig(:agent_task, :source_files)).reject(&:blank?)
    end

    def attach_source_files!(source_files)
      RosAgent::SourceArtifactUploader.new(
        task: @task,
        files: source_files,
        created_by: current_user
      ).call
    end

    def enqueue_runner(mode)
      job_class = runner_job_class
      return false unless job_class

      job_class.perform_later(@task.id, mode: mode)
      true
    end

    def runner_job_class
      return unless RosAgent.const_defined?(:RunTaskJob, false)

      RosAgent.const_get(:RunTaskJob)
    end

    def run_of_show_calendar
      @event.run_of_show_calendar || @event.event_calendars.create!(
        name: "Run of Show",
        timezone: EventCalendar::DEFAULT_TIMEZONE,
        kind: EventCalendar::KINDS[:master]
      )
    end

    def require_high_risk_acknowledgement!
      return true unless @task.high_risk_plan?
      return true if @task.high_risk_acknowledged?

      unless ActiveModel::Type::Boolean.new.cast(params[:high_risk_acknowledgement])
        redirect_to event_ros_agent_task_path(@event, @task), alert: "Acknowledge high-risk operations before continuing."
        return false
      end

      @task.acknowledge_high_risk!(user: current_user)
      true
    end

    def disable_response_cache!
      response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, max-age=0"
      response.headers["Pragma"] = "no-cache"
      response.headers["Expires"] = "0"
    end

    def task_status_snapshot
      question_batch = open_question_batch_for(@task)
      canvas_state = canvas_state_for(@task, question_batch)
      snapshot = {
        status: @task.status,
        active: active_status?(@task),
        status_label: status_label_for(@task),
        action_anchor: action_anchor_for(@task),
        canvas_state: canvas_state,
        source_files: source_file_artifacts.map { |artifact| serialize_source_file(artifact) },
        llm_calls: @task.llm_calls.order(:started_at, :created_at, :id).map { |call| serialize_llm_call(call) },
        task_events: @task.events.includes(:created_by).order(created_at: :asc, id: :asc).map { |event| serialize_task_event(event) },
        last_error: @task.respond_to?(:last_error_json) ? @task.last_error_json.presence : nil
      }
      snapshot[:canvas_html] = canvas_html_for(@task, question_batch, canvas_state)
      snapshot[:bottom_rail_html] = bottom_rail_html_for(@task, snapshot, canvas_state)
      snapshot[:metadata_html] = metadata_html_for(@task, snapshot)
      snapshot[:canvas_metadata_html] = canvas_metadata_html_for(@task, snapshot, canvas_state, question_batch)
      snapshot[:action_sections_html] = snapshot[:canvas_html]
      snapshot
    end

    def source_file_artifacts
      @task.artifacts
           .where(source_kind: AgentTaskArtifact::SOURCE_KINDS[:source_document])
           .order(:position)
    end

    def active_status?(task)
      return true if in_flight_llm_call?(task)
      return true if task.drafting? && draft_refinement_pending?(task)
      return false if task.drafting? && task.draft_ros_json.present?

      %w[draft analyzing drafting planning applying].include?(task.status.to_s)
    end

    def status_label_for(task)
      return task.status.to_s.titleize if in_flight_llm_call?(task)
      return "Draft Ready" if task.drafting? && task.draft_ros_json.present? && !draft_refinement_pending?(task)

      task.status.to_s.titleize
    end

    def action_anchor_for(task)
      return "planning-questions" if task.needs_input? && task.question_batches.open.exists?
      return "review-plan" if task.ready_for_review? && task.preview_json.present?
      return "draft-ros" if task.drafting? && task.draft_ros_json.present?

      nil
    end

    def in_flight_llm_call?(task)
      task.llm_calls.pending.where(started_at: 15.minutes.ago..).exists?
    end

    def draft_refinement_pending?(task)
      task.events.order(created_at: :desc, id: :desc).limit(1).pick(:event_type) == "draft_refinement_requested"
    end

    def open_question_batch_for(task)
      task.question_batches.open.order(:position).last
    end

    def canvas_state_for(task, question_batch)
      return "plan" if task.preview_json.present? && (task.ready_for_review? || task.approved? || task.applying? || task.applied?)
      return "questions" if task.needs_input? && question_batch.present?
      return "draft" if task.planning? && task.draft_ros_json.present?
      return "working" if working_canvas?(task)
      return "plan" if task.preview_json.present?
      return "draft" if task.draft_ros_json.present?
      return "questions" if question_batch.present?

      "working"
    end

    def working_canvas?(task)
      active_status?(task) && !task.planning? && !task.preview_json.present?
    end

    def canvas_html_for(task, question_batch, canvas_state)
      render_to_string(
        partial: "events/ros_agent_tasks/canvas_content",
        formats: [:html],
        locals: {
          event: @event,
          task: task,
          question_batch: question_batch,
          canvas_state: canvas_state,
          show_details: true
        }
      )
    end

    def bottom_rail_html_for(task, status_snapshot, canvas_state)
      render_to_string(
        partial: "events/ros_agent_tasks/bottom_rail_content",
        formats: [:html],
        locals: {
          event: @event,
          task: task,
          status_snapshot: status_snapshot,
          canvas_state: canvas_state
        }
      )
    end

    def metadata_html_for(task, status_snapshot)
      render_to_string(
        partial: "events/ros_agent_tasks/metadata",
        formats: [:html],
        locals: {
          task: task,
          status_snapshot: status_snapshot
        }
      )
    end

    def canvas_metadata_html_for(task, status_snapshot, canvas_state, question_batch)
      render_to_string(
        partial: "events/ros_agent_tasks/canvas_metadata",
        formats: [:html],
        locals: {
          task: task,
          status_snapshot: status_snapshot,
          canvas_state: canvas_state,
          question_batch: question_batch
        }
      )
    end

    def action_sections_html_for(task)
      render_to_string(
        partial: "events/ros_agent_tasks/action_sections",
        formats: [:html],
        locals: {
          task: task,
          question_batch: open_question_batch_for(task)
        }
      )
    end

    def serialize_source_file(artifact)
      {
        filename: artifact.filename,
        size_bytes: artifact.size_bytes,
        size_label: artifact.size_bytes.present? ? helpers.number_to_human_size(artifact.size_bytes) : nil,
        openai_state: artifact.openai_file_id.present? ? "ready" : "pending",
        openai_file_id: artifact.openai_file_id,
        source_kind: artifact.source_kind,
        position: artifact.position
      }
    end

    def serialize_llm_call(call)
      {
        purpose: call.purpose,
        status: call.status,
        model: call.model,
        duration_ms: call.duration_ms,
        duration_label: call.duration_ms.present? ? "#{call.duration_ms} ms" : nil,
        error: call.error_json,
        usage: call.usage_json,
        started_at: call.started_at&.iso8601,
        completed_at: call.completed_at&.iso8601,
        attempt: call.attempt
      }
    end

    def serialize_task_event(event)
      {
        event_type: event.event_type,
        message: event.message,
        created_at: event.created_at&.iso8601,
        created_at_label: event.created_at ? helpers.l(event.created_at, format: :short) : nil,
        created_by: event.created_by&.name.presence || event.created_by&.email
      }
    end
  end
end
