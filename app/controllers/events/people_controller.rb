module Events
  class PeopleController < ApplicationController
    before_action :set_event

    def show
      @key_people = @event.event_guests.key_people.ordered
      @key_person_groups = @event.event_key_person_groups.includes(:event_calendar_tag, :event_guests).ordered
      @key_people_group_options = @key_person_groups.map { |group| [group.name, group.id.to_s] }
      @new_event_guest = @event.event_guests.new(kind: EventGuest::KINDS[:key_person], vip: false)
      @planner_team_members = @event.planner_team_members.includes(:user).order(:position)
      @client_team_members = @event.client_team_members.includes(:user).order(:position)
      @vendors = @event.event_vendors.includes(:event).ordered
      @venues = @event.event_venues.includes(:event).ordered
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end
  end
end
