require "uri"

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  before_action :require_login

  helper_method :current_user, :logged_in?

  private

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def logged_in?
    current_user.present?
  end

  def require_login
    return if logged_in? || User.none?

    redirect_to login_path, alert: "Please log in to continue."
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
