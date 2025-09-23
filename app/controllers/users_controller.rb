class UsersController < ApplicationController
  skip_before_action :require_login, only: %i[new create], if: -> { User.none? }

  def index
    @users = User.order(:name)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)

    if @user.save
      handle_post_create_redirect
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end

  def handle_post_create_redirect
    if User.count == 1
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome aboard!"
    else
      redirect_to users_path, notice: "User created."
    end
  end
end
