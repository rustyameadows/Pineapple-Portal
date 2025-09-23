class UsersController < ApplicationController
  skip_before_action :require_login, only: %i[new create], if: -> { User.none? }
  before_action :set_user, only: %i[edit update]

  def index
    @users = User.order(:name)
  end

  def new
    @user = User.new
    @user.role = User.none? ? "admin" : "planner"
  end

  def create
    @user = User.new(user_params)
    assign_role_for_context

    if @user.save
      handle_post_create_redirect
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def edit; end

  def update
    if @user.update(user_params)
      redirect_to users_path, notice: "User updated."
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    permitted = %i[name email password password_confirmation title phone_number]
    permitted << :role if allow_role_param?
    params.require(:user).permit(permitted)
  end

  def allow_role_param?
    User.none? || current_user&.admin?
  end

  def assign_role_for_context
    if User.none?
      @user.role = "admin"
    elsif !current_user&.admin?
      @user.role = "planner"
    end
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
