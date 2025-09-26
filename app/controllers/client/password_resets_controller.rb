module Client
  class PasswordResetsController < ApplicationController
    skip_before_action :require_login
    before_action :load_reset_token

    def show
      if @reset_token.expired? || @reset_token.redeemed_at?
        @token_invalid = true
      end
    end

    def update
      if @reset_token.expired? || @reset_token.redeemed_at?
        @token_invalid = true
        flash.now[:alert] = "This reset link has expired. Ask your planner for a new one."
        render :show, status: :unprocessable_content and return
      end

      payload = reset_params

      if payload[:password].blank?
        flash.now[:alert] = "Password can't be blank."
        render :show, status: :unprocessable_content and return
      end

      unless payload[:password] == payload[:password_confirmation]
        flash.now[:alert] = "Passwords do not match."
        render :show, status: :unprocessable_content and return
      end

      if payload[:password].length < 8
        flash.now[:alert] = "Password must be at least 8 characters."
        render :show, status: :unprocessable_content and return
      end

      if @reset_token.user.update(password: payload[:password], password_confirmation: payload[:password_confirmation])
        @reset_token.redeem!
        session[:client_user_id] = @reset_token.user.id

        if (event = first_client_event(@reset_token.user))
          redirect_to client_event_path(event), notice: "Password updated. Welcome back to your portal."
        else
          redirect_to client_login_path, notice: "Password updated. Sign in once your planner grants portal access."
        end
      else
        flash.now[:alert] = @reset_token.user.errors.full_messages.to_sentence
        render :show, status: :unprocessable_content
      end
    end

    private

    def load_reset_token
      @reset_token = PasswordResetToken.find_by(token: params[:token].to_s)
      unless @reset_token
        redirect_to client_login_path, alert: "That reset link is no longer valid." and return
      end
      @client_user = @reset_token.user
    end

    def reset_params
      params.require(:password_reset).permit(:password, :password_confirmation)
    end

    def first_client_event(user)
      user.events_as_team_member
          .where(event_team_members: { member_role: EventTeamMember::TEAM_ROLES[:client], client_visible: true })
          .first
    end
  end
end
