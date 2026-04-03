module EventsSettingsPageSupport
  extend ActiveSupport::Concern

  private

  def render_settings_page_for(return_to_path)
    case normalize_settings_return_to(return_to_path)
    when event_settings_path(@event)
      prepare_general_settings
      render "events/settings/show", status: :unprocessable_content
      true
    when client_portal_event_settings_path(@event)
      prepare_client_portal_settings
      render "events/settings/client_portal", status: :unprocessable_content
      true
    else
      false
    end
  end

  def prepare_general_settings
    prepare_internal_links
  end

  def prepare_client_portal_settings
    prepare_quick_links
  end

  def prepare_quick_links
    @planning_event_link = @event.event_links.new(link_type: "planning")
    @quick_event_link = @event.event_links.new(link_type: "quick")
    @financial_event_link = @event.event_links.new(link_type: "financial")

    @quick_event_links = @event.event_links.quick.ordered
    @financial_event_links = @event.event_links.financial.ordered

    @planning_link_entries = @event.ordered_planning_link_entries
    @hidden_planning_links = hidden_built_in_planning_links
    @financial_documents = @event.documents.latest.where.not(storage_uri: nil).order(updated_at: :desc, title: :asc)
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

  def prepare_internal_links
    @internal_event_link = @event.event_links.new(link_type: "internal")
    @internal_event_links = @event.event_links.internal.ordered
  end

  def normalize_settings_return_to(return_to_path)
    return_to_path.to_s.split("?").first
  end
end
