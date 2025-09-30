module Events
  class SettingsController < ApplicationController
    before_action :set_event
    helper CalendarHelper

    def show
    end

    def client_portal
      prepare_quick_links
    end

    def clients
      prepare_client_team
    end

    def vendors
      prepare_vendors
    end

    def locations
      prepare_locations
    end

    def planners
      prepare_planner_team
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def prepare_quick_links
      @planning_event_link = @event.event_links.new(link_type: "planning")
      @quick_event_link = @event.event_links.new(link_type: "quick")

      @quick_event_links = @event.event_links.quick.ordered

      @planning_link_entries = @event.ordered_planning_link_entries
      @hidden_planning_links = hidden_built_in_planning_links
    end

    def prepare_vendors
      @event_vendor = @event.event_vendors.new(client_visible: true)
      @event_vendors = @event.event_vendors.ordered
    end

    def prepare_locations
      @event_venue = @event.event_venues.new(client_visible: true)
      @event_venues = @event.event_venues.ordered
    end

    def prepare_planner_team
      @planner_team_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:planner]
      )

      @planner_team_members = @event.planner_team_members
                                    .includes(:user)
                                    .left_joins(:user)
                                    .ordered_for_display
                                    .order("users.name")

      assigned_user_ids = @event.event_team_members.pluck(:user_id)

      @available_planners = User.planners.order(:name)
      @available_planners = @available_planners.where.not(id: assigned_user_ids) if assigned_user_ids.any?
    end

    def prepare_client_team
      @client_team_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:client]
      )
      @client_team_member.client_user_attributes = {}

      @client_team_members = @event.client_team_members
                                   .includes(user: :password_reset_tokens)
                                   .left_joins(:user)
                                   .order("users.name")

      @client_link_member = @event.event_team_members.new(
        member_role: EventTeamMember::TEAM_ROLES[:client]
      )

      assigned_user_ids = @event.event_team_members.pluck(:user_id)

      @available_clients = User.clients.order(:name)
      @available_clients = @available_clients.where.not(id: assigned_user_ids) if assigned_user_ids.any?
    end

    def hidden_built_in_planning_links
      visible_keys = @event.planning_link_keys

      ClientPortal::PlanningLinks
        .built_in_links_for(@event)
        .reject { |link| visible_keys.include?(link.key) }
    end

  end
end
