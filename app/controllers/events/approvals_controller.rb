module Events
  class ApprovalsController < ApplicationController
    before_action :set_event
    before_action :set_approval, only: %i[show edit update destroy]

    def index
      @approvals = @event.approvals.ordered
    end

    def show; end

    def new
      @approval = @event.approvals.new
    end

    def create
      @approval = @event.approvals.new(approval_params)

      if @approval.save
        redirect_to event_approval_path(@event, @approval), notice: "Approval created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @approval.update(approval_params)
        redirect_to event_approval_path(@event, @approval), notice: "Approval updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @approval.destroy
      redirect_to event_approvals_path(@event), notice: "Approval removed."
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_approval
      @approval = @event.approvals.find(params[:id])
    end

    def approval_params
      params.require(:approval).permit(:title, :summary, :instructions, :client_visible, :status, :client_name, :client_note, :acknowledged_at)
    end
  end
end
