module Events
  class PeopleController < ApplicationController
    before_action :set_event

    def show
      @planner_team_members = @event.planner_team_members.includes(:user).order(:position)
      @client_team_members = @event.client_team_members.includes(:user).order(:position)
      @vendors = @event.event_vendors.includes(:event).ordered
      @venues = @event.event_venues.includes(:event).ordered
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
