class SessionsController < ApplicationController
  skip_before_action :require_login, only: %i[new create]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    email = params[:email].to_s.strip.downcase
    user = User.find_by(email: email)

    if user&.planner_or_admin? && user.authenticate(params[:password])
      session[:user_id] = user.id
      redirect_to root_path, notice: "Welcome back!"
    elsif user&.client? && user.authenticate(params[:password])
      redirect_to client_login_path, alert: "Client portal accounts sign in through the client portal login."
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_content
    end
  end

  def destroy
    reset_session
    @current_user = nil
    redirect_to login_path, notice: "Logged out."
  end
end
