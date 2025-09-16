class UsersController < ApplicationController
  def create
    @user = User.new(user_params)

    if @user.save
      redirect_to root_path, notice: "User created."
    else
      @users = User.order(created_at: :desc)
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render "welcome/home", status: :unprocessable_content
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email)
  end
end
