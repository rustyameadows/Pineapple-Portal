module ClientPortalAuthentication
  extend ActiveSupport::Concern

  included do
    helper_method :current_client_user,
                  :client_logged_in?,
                  :client_has_multiple_accessible_events?,
                  :client_portal_event_key if respond_to?(:helper_method)
  end

  private

  def current_client_user
    @current_client_user ||= User.clients.find_by(id: session[:client_user_id]) if session[:client_user_id]
  end

  def client_logged_in?
    current_client_user.present?
  end

  def reset_client_session
    session.delete(:client_user_id)
    @current_client_user = nil
  end

  def accessible_client_events(user = current_client_user)
    return Event.none unless user&.client?

    Event.joins(:client_team_members)
         .where(event_team_members: {
           user_id: user.id,
           member_role: EventTeamMember::TEAM_ROLES[:client],
           client_visible: true
         })
         .order(Arel.sql("COALESCE(events.starts_on, events.updated_at, events.created_at) ASC"))
         .order(:name, :id)
  end

  def client_has_multiple_accessible_events?
    accessible_client_events.limit(2).pluck(:id).length > 1
  end

  def client_can_access_event?(user, event)
    return false unless user&.client? && event.present?

    accessible_client_events(user).where(id: event.id).exists?
  end

  def client_portal_event_key(event)
    event.portal_slug.presence || event.id
  end
end
