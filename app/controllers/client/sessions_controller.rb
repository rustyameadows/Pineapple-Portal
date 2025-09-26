module Client
  class SessionsController < ApplicationController

    skip_before_action :require_login

    def new
      if session[:client_user_id].present?
        if (event = first_client_event(User.find_by(id: session[:client_user_id])))
          redirect_to client_event_path(event)
        else
          session.delete(:client_user_id)
        end
      end
    end

    def create
      email = params[:email].to_s.strip.downcase
      user = User.clients.find_by(email: email)

      if authenticate_client(user)
        if (event = first_client_event(user))
          session[:client_user_id] = user.id
          redirect_to client_event_path(event), notice: "Welcome to your client portal."
        else
          flash.now[:alert] = "No events are linked to this account yet."
          render :new, status: :unprocessable_content
        end
      else
        flash.now[:alert] = "Invalid email or password."
        render :new, status: :unprocessable_content
      end
    end

    def destroy
      session.delete(:client_user_id)
      redirect_to client_login_path, notice: "Signed out of the client portal."
    end

    private

    def authenticate_client(user)
      return false unless user&.authenticate(params[:password])
      user.events_as_team_member
          .where(event_team_members: { member_role: EventTeamMember::TEAM_ROLES[:client], client_visible: true })
          .exists?
    end

    def first_client_event(user)
      return nil unless user&.client?

      user.events_as_team_member
          .where(event_team_members: { member_role: EventTeamMember::TEAM_ROLES[:client], client_visible: true })
          .first
    end
  end
end
