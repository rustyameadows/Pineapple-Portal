module Events
  class SettingsController < ApplicationController
    before_action :set_event
    helper CalendarHelper

    def show
      @event_link = @event.event_links.new
      @event_links = @event.event_links.ordered
      @planner_team_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:planner]
      )

      @client_team_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:client]
      )
      @client_team_member.client_user_attributes = {}

      @planner_team_members = @event.planner_team_members
                                    .includes(:user)
                                    .left_joins(:user)
                                    .ordered_for_display
                                    .order("users.name")

      @client_team_members = @event.client_team_members
                                   .includes(:user)
                                   .left_joins(:user)
                                   .order("users.name")

      @client_link_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:client]
      )

      assigned_user_ids = (@planner_team_members + @client_team_members).map(&:user_id)

      @available_planners = User.planners.order(:name)
      @available_planners = @available_planners.where.not(id: assigned_user_ids) if assigned_user_ids.any?

      @available_clients = User.clients.order(:name)
      @available_clients = @available_clients.where.not(id: assigned_user_ids) if assigned_user_ids.any?

      @calendar = @event.run_of_show_calendar
      if @calendar.nil?
        @calendar = @event.event_calendars.create!(
          name: "Run of Show",
          timezone: EventCalendar::DEFAULT_TIMEZONE
        )
      end

      @milestone_items = @calendar.calendar_items
                                   .includes(:event_calendar_tags, :team_members)
                                   .select(&:milestone?)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
