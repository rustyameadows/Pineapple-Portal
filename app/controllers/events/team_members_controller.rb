module Events
  class TeamMembersController < ApplicationController
    before_action :set_event
    before_action :set_team_member, only: %i[update destroy]

    def create
      @team_member = @event.event_team_members.new(team_member_params)

      if @team_member.save
        redirect_to event_settings_path(@event), notice: "Planner added to the event."
      else
        redirect_to event_settings_path(@event), alert: @team_member.errors.full_messages.to_sentence
      end
    end

    def update
      if @team_member.update(team_member_update_params)
        redirect_to event_settings_path(@event), notice: "Visibility updated."
      else
        redirect_to event_settings_path(@event), alert: @team_member.errors.full_messages.to_sentence
      end
    end

    def destroy
      @team_member.destroy
      redirect_to event_settings_path(@event), notice: "Planner removed from the event."
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_team_member
      @team_member = @event.event_team_members.find(params[:id])
    end

    def team_member_params
      params.require(:event_team_member).permit(:user_id)
    end

    def team_member_update_params
      params.require(:event_team_member).permit(:client_visible)
    end
  end
end
