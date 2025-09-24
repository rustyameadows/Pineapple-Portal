module Events
  class SettingsController < ApplicationController
    before_action :set_event
    helper CalendarHelper

    def show
      @event_link = @event.event_links.new
      @event_links = @event.event_links.ordered
      @team_member = @event.event_team_members.new
      @team_members = @event.event_team_members.includes(:user).references(:users).order("users.name")
      assigned_user_ids = @team_members.map(&:user_id)
      @available_planners = User.where(role: [User::ROLES[:planner], User::ROLES[:admin]]).order(:name)
      @available_planners = @available_planners.where.not(id: assigned_user_ids) if assigned_user_ids.any?

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
