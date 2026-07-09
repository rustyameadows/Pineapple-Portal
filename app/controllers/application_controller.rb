require "uri"

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login

  helper_method :current_user,
                :logged_in?,
                :admin_user?,
                :accessible_events_scope,
                :current_user_can_access_event?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def admin_user?
    current_user&.account? && current_user&.admin?
  end

  def accessible_events_scope
    return Event.none unless current_user&.planner_or_admin?
    return Event.all if admin_user?

    Event.where(
      id: EventTeamMember.where(
        user_id: current_user.id,
        member_role: EventTeamMember::TEAM_ROLES[:planner]
      ).select(:event_id)
    )
  end

  def current_user_can_access_event?(event)
    return false unless event && current_user&.planner_or_admin?
    return true if admin_user?

    event.event_team_members.exists?(
      user_id: current_user.id,
      member_role: EventTeamMember::TEAM_ROLES[:planner]
    )
  end

  def require_login
    return if logged_in? || User.none?

    redirect_to login_path, alert: "Please log in to continue."
  end

  def require_admin!
    return if admin_user?

    redirect_to root_path, alert: "Admin access is required."
  end

  def find_accessible_event!(id)
    accessible_events_scope.find(id)
  end

  def safe_return_to(fallback: root_path)
    safe_local_path(params[:return_to], fallback: fallback)
  end

  def safe_local_path(target, fallback: nil)
    value = target.to_s.strip
    return fallback if value.blank?

    uri = URI.parse(value)
    if uri.host.nil? && uri.scheme.nil?
      value
    elsif uri.host == request.host
      [uri.path.presence || "/", uri.query.present? ? "?#{uri.query}" : nil].join
    else
      fallback
    end
  rescue URI::InvalidURIError
    fallback
  end
end
