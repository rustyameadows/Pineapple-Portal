module Events
  class TeamMembersController < ApplicationController
    before_action :set_event
    before_action :set_team_member, only: %i[update destroy issue_reset]

    def create
      attributes = team_member_params.to_h
      client_user_data = attributes.delete("client_user_attributes")
      generated_password = nil

      attributes = attributes.with_indifferent_access

      attributes[:client_visible] = true unless attributes.key?(:client_visible)
      attributes[:member_role] = EventTeamMember::TEAM_ROLES[:planner] if attributes[:member_role].blank?

      target_path = attributes[:member_role] == EventTeamMember::TEAM_ROLES[:client] ? clients_event_settings_path(@event) : planners_event_settings_path(@event)

      if attributes[:member_role] == EventTeamMember::TEAM_ROLES[:client]
        attributes[:client_visible] = true unless attributes.key?(:client_visible)

        if attributes[:user_id].blank?
          if client_user_data.present?
            user, generated_password = build_client_user(client_user_data)
            unless user.save
              redirect_to target_path, alert: user.errors.full_messages.to_sentence and return
            end
            attributes[:user_id] = user.id
          else
            redirect_to target_path, alert: "Select an existing client or enter details to invite one." and return
          end
        end
      elsif attributes[:member_role] == EventTeamMember::TEAM_ROLES[:planner]
        if attributes[:user_id].blank?
          redirect_to target_path, alert: "Select an existing planner." and return
        end
      end

      @team_member = @event.event_team_members.new(attributes)

      if @team_member.save
        reset_token = nil
        if @team_member.client? && generated_password
          reset_token = PasswordResetToken.generate_for!(
            user: @team_member.user,
            issued_by: current_user
          )
          flash[:highlight_reset_token_id] = reset_token.id
        end

        notice = if @team_member.client?
                   if reset_token
                     "Client account created. Reset link generated below."
                   else
                     "Client access granted."
                   end
                 else
                   "Planner added to the event."
                 end
        redirect_to @team_member.client? ? clients_event_settings_path(@event) : planners_event_settings_path(@event), notice: notice
      else
        redirect_to target_path, alert: @team_member.errors.full_messages.to_sentence
      end
    end

    def update
      if @team_member.update(team_member_update_params)
        message = @team_member.client? ? "Client access updated." : "Team member updated."
        redirect_to @team_member.client? ? clients_event_settings_path(@event) : planners_event_settings_path(@event), notice: message
      else
        redirect_to @team_member.client? ? clients_event_settings_path(@event) : planners_event_settings_path(@event), alert: @team_member.errors.full_messages.to_sentence
      end
    end

    def destroy
      @team_member.destroy
      redirect_to @team_member.client? ? clients_event_settings_path(@event) : planners_event_settings_path(@event), notice: "Team member removed from the event."
    end

    def issue_reset
      unless @team_member.client?
        redirect_to planners_event_settings_path(@event), alert: "Password resets are only available for client accounts." and return
      end

      token = PasswordResetToken.generate_for!(
        user: @team_member.user,
        issued_by: current_user
      )

      flash[:notice] = "Reset link generated. Share the link shown below with your client."
      flash[:highlight_reset_token_id] = token.id
      redirect_to clients_event_settings_path(@event)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_team_member
      @team_member = @event.event_team_members.find(params[:id])
    end

    def team_member_params
      normalize_team_member_attributes(
        params.require(:event_team_member).permit(:user_id, :client_visible, :lead_planner, :position, :member_role,
                                                  client_user_attributes: %i[name email phone_number])
      )
    end

    def team_member_update_params
      normalize_team_member_attributes(
        params.require(:event_team_member).permit(:client_visible, :lead_planner, :position, :member_role)
      )
    end

    def normalize_team_member_attributes(permitted_params)
      permitted_params[:position] = permitted_params[:position].presence&.to_i if permitted_params.key?(:position)
      if permitted_params.key?(:member_role)
        permitted_params[:member_role] = permitted_params[:member_role].presence&.to_s
      end
      if permitted_params[:client_user_attributes].is_a?(ActionController::Parameters)
        permitted_params[:client_user_attributes] = permitted_params[:client_user_attributes]
                                                .permit(:name, :email, :phone_number)
                                                .to_h
      end
      permitted_params
    end

    def build_client_user(attrs)
      attrs = attrs.to_h.symbolize_keys
      password = SecureRandom.alphanumeric(12)

      user = User.new(
        name: attrs[:name],
        email: attrs[:email],
        phone_number: attrs[:phone_number],
        role: User::ROLES[:client],
        password: password,
        password_confirmation: password
      )

      [user, password]
    end
  end
end
