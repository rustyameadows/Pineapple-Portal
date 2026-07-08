module Events
  class ClientUsersController < ApplicationController
    before_action :set_event
    before_action :require_admin!
    before_action :set_client_user

    def edit
      @return_to = params[:return_to].presence || clients_event_settings_path(@event)
    end

    def update
      @return_to = params[:return_to].presence || clients_event_settings_path(@event)

      if @user.update(client_user_params)
        redirect_to safe_return_to(fallback: clients_event_settings_path(@event)), notice: "Client user updated."
      elsif inline_financial_update?
        redirect_to safe_return_to(fallback: clients_event_settings_path(@event)), alert: @user.errors.full_messages.to_sentence
      else
        flash.now[:alert] = @user.errors.full_messages.to_sentence
        render :edit, status: :unprocessable_content
      end
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end

    def set_client_user
      @user = @event.client_users.find(params[:id])
      @client_team_member = @event.client_team_members.includes(:user).find_by!(user_id: @user.id)
    end

    def client_user_params
      params.require(:user).permit(
        :name,
        :email,
        :phone_number,
        :general_notes,
        :dietary_restrictions,
        :can_view_financials,
        :password,
        :password_confirmation
      )
    end

    def inline_financial_update?
      user_params = params[:user]
      return false unless user_params.respond_to?(:keys)

      user_params.keys.map(&:to_s).sort == ["can_view_financials"]
    end
  end
end
