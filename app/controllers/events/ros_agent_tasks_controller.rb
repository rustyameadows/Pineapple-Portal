module Events
  class RosAgentTasksController < ApplicationController
    before_action :set_event
    before_action :set_task, only: %i[show answer_questions refine_draft request_final_plan approve apply]

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
      @open_question_batch = @task.question_batches.open.order(:position).last
      @task_events = @task.events.includes(:created_by).order(created_at: :asc, id: :asc)
      @artifacts = @task.artifacts.order(:position)
    end

    def answer_questions
      batch = @task.question_batches.open.order(:position).last
      unless batch
        redirect_to event_ros_agent_task_path(@event, @task), alert: "There are no open questions to answer."
        return
      end

      batch.answer!(answers_params)
      @task.append_event!(
        event_type: "questions_answered",
        message: "Planner answered agent questions.",
        payload: { answers: answers_params },
        created_by: current_user
      )
      enqueue_runner(:initial_run)
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
      @event = Event.find(params[:event_id])
    end

    def set_task
      @task = @event.agent_tasks.find(params[:id])
    end

    def task_params
      params.require(:agent_task).permit(:prompt, :mode)
    end

    def answers_params
      params.fetch(:answers, {}).permit!.to_h
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
  end
end
