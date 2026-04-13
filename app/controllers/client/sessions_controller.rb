module Client
  class SessionsController < ApplicationController
    include ClientPortalAuthentication

    skip_before_action :require_login

    def new
      reset_client_session if session[:client_user_id].present? && current_client_user.nil?
      return unless current_client_user

      if (target = accessible_return_to(current_client_user, params[:return_to]))
        redirect_to target and return
      end

      @accessible_events = accessible_client_events(current_client_user).to_a

      if @accessible_events.empty?
        reset_client_session
        flash.now[:alert] ||= "No events are linked to this account yet."
      elsif @accessible_events.one?
        redirect_to client_event_path(client_portal_event_key(@accessible_events.first))
      else
        render :events
      end
    end

    def create
      email = params[:email].to_s.strip.downcase
      user = User.clients.find_by(email: email)

      if user&.authenticate(params[:password])
        unless accessible_client_events(user).exists?
          flash.now[:alert] = "No events are linked to this account yet."
          render :new, status: :unprocessable_content and return
        end

        session[:client_user_id] = user.id
        redirect_to client_login_redirect_path(return_to: params[:return_to]),
                    notice: "Welcome to your client portal."
      else
        flash.now[:alert] = "Invalid email or password."
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      reset_client_session
      redirect_to client_login_path, notice: "Signed out of the client portal."
    end

    private

    def client_login_redirect_path(return_to:)
      target = safe_local_path(return_to)
      return client_login_path unless target

      client_login_path(return_to: target)
    end

    def accessible_return_to(user, target)
      safe_target = safe_local_path(target)
      return unless safe_target

      route = recognize_local_path(safe_target)
      return unless route

      event = event_for_return_route(route)
      return unless client_can_access_event?(user, event)

      safe_target
    end

    def recognize_local_path(target)
      uri = URI.parse(target)
      Rails.application.routes.recognize_path(uri.path, method: :get)
    rescue URI::InvalidURIError, ActionController::RoutingError
      nil
    end

    def event_for_return_route(route)
      case route[:controller]
      when /\Aclient\//
        slug = route[:event_slug].presence
        return unless slug

        Event.find_by(portal_slug: slug) || Event.find_by(id: slug)
      when "documents"
        return unless route[:action] == "download"

        Event.find_by(id: route[:event_id])
      end
    end
  end
end
