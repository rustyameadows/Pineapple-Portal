class UsersController < ApplicationController
  skip_before_action :require_login, only: %i[new create], if: -> { User.none? }

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      session[:user_id] = @user.id unless logged_in?
      redirect_to root_path, notice: "User created."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence

      if logged_in?
        @users = User.order(created_at: :desc)
        render "welcome/home", status: :unprocessable_content
      else
        render :new, status: :unprocessable_content
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
