module Events
  class PeopleController < ApplicationController
    before_action :set_event

    def show
      @key_people = @event.event_guests.key_people.ordered
      @key_people_group_options = @key_people.map(&:group_name).filter_map(&:presence).uniq
      @new_event_guest = @event.event_guests.new(kind: EventGuest::KINDS[:key_person], vip: false)
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
