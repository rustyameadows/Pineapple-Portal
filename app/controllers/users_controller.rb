class UsersController < ApplicationController
  ACCESS_TYPE_ATTRIBUTES = {
    "admin" => { role: User::ROLES[:admin], account_kind: User::ACCOUNT_KINDS[:account] },
    "planner" => { role: User::ROLES[:planner], account_kind: User::ACCOUNT_KINDS[:account] },
    "planner_contact" => { role: User::ROLES[:planner], account_kind: User::ACCOUNT_KINDS[:contact] },
    "client" => { role: User::ROLES[:client], account_kind: User::ACCOUNT_KINDS[:account] }
  }.freeze
  ACCESS_TYPE_LABELS = {
    "admin" => "Admin",
    "planner" => "Planner",
    "planner_contact" => "Planner Contact",
    "client" => "Client"
  }.freeze

  skip_before_action :require_login, only: %i[new create], if: -> { User.none? }
  before_action :require_admin!, unless: :first_user_signup?
  before_action :set_user, only: %i[edit update]
  before_action :set_user_for_destroy, only: %i[destroy]
  helper_method :access_type_for_user, :access_type_label_for_user, :access_type_options_for_roles

  def index
    @show_clients = params[:show_clients] == "1"
    @users = User.order(:name)
    @users = @users.where.not(role: User::ROLES[:client]) unless @show_clients
    @users = @users.to_a
    @user_roster_groups = user_roster_groups(@users)
  end

  def new
    @user = User.new
    requested_role = params[:role].presence_in(User.roles.keys)

    if User.none?
      @user.role = "admin"
    elsif requested_role.present? && (current_user&.admin? || current_user&.planner?)
      @user.role = requested_role
    else
      @user.role = "planner"
    end

    @return_to = params[:return_to]
    @allow_role_select = allow_role_selection?
    @role_options = role_options_for_current_user
  end

  def create
    @user = User.new(user_params)
    assign_role_for_context
    @return_to = params[:return_to]
    @allow_role_select = allow_role_selection?
    @role_options = role_options_for_current_user

    if @user.save
      handle_post_create_redirect
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :new, status: :unprocessable_content
    end
  end

  def edit
    @return_to = params[:return_to]
    @allow_role_select = allow_role_selection?
    @role_options = role_options_for_current_user
  end

  def update
    @return_to = params[:return_to]
    @allow_role_select = allow_role_selection?
    @role_options = role_options_for_current_user

    if @user.update(user_params)
      redirect_to(@return_to.presence || users_path, notice: "User updated.")
    else
      flash.now[:alert] = @user.errors.full_messages.to_sentence
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @user.destroy
      redirect_to users_path, notice: "User removed."
    else
      redirect_to users_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  private

  def set_user
    @user = User.find(params[:id])
  end

  def first_user_signup?
    User.none? && action_name.in?(%w[new create])
  end

  def set_user_for_destroy
    @user = User.find(params[:id])
  end

  def user_params
    permitted = %i[
      name
      email
      password
      password_confirmation
      title
      phone_number
      account_kind
      general_notes
      dietary_restrictions
      can_view_financials
      access_type
    ]
    permitted << :role if allow_role_param?
    attributes = params.require(:user).permit(permitted)
    apply_access_type_param(attributes)
    sanitize_role_param(attributes)
    attributes
  end

  def allow_role_param?
    return true if User.none?
    return true if current_user&.admin?
    current_user&.planner?
  end

  def assign_role_for_context
    if User.none?
      @user.role = "admin"
      return
    end

    role_param_present = params[:user]&.key?(:role)
    desired_role = params[:user][:role].presence if role_param_present

    unless role_param_present
      @user.role ||= User::ROLES[:planner]
      return
    end

    allowed_roles = allowed_roles_for_current_user
    fallback_role = @user.role || allowed_roles.first || User::ROLES[:planner]
    @user.role = if desired_role.present? && allowed_roles.include?(desired_role)
                   desired_role
                 else
                   fallback_role
                 end
  end

  def handle_post_create_redirect
    if params[:return_to].present?
      redirect_to params[:return_to], notice: "User created."
    elsif User.count == 1
      session[:user_id] = @user.id
      redirect_to root_path, notice: "Welcome aboard!"
    else
      redirect_to users_path, notice: "User created."
    end
  end

  def allow_role_selection?
    User.none? || current_user&.admin? || current_user&.planner?
  end

  def role_options_for_current_user
    allowed_roles_for_current_user
  end

  def sanitize_role_param(attributes)
    return unless attributes.key?(:role)
    value = attributes[:role].presence
    allowed = allowed_roles_for_current_user
    attributes[:role] = allowed.include?(value) ? value : allowed.first
  end

  def apply_access_type_param(attributes)
    return unless attributes.key?(:access_type)

    access_type = attributes.delete(:access_type).to_s
    access_attributes = ACCESS_TYPE_ATTRIBUTES[access_type]
    return unless access_attributes
    return unless allowed_roles_for_current_user.include?(access_attributes[:role])

    attributes[:role] = access_attributes[:role]
    attributes[:account_kind] = access_attributes[:account_kind]
  end

  def allowed_roles_for_current_user
    if User.none? || current_user&.admin?
      User.roles.values
    elsif current_user&.planner?
      [User::ROLES[:planner], User::ROLES[:client]]
    else
      [User::ROLES[:planner]]
    end
  end

  def user_roster_groups(users)
    groups = [
      {
        id: "admin",
        title: "Admin",
        users: users.select(&:admin?)
      },
      {
        id: "planner-accounts",
        title: "Planner Accounts",
        users: users.select { |user| user.planner? && !user.contact? }
      },
      {
        id: "planner-contacts",
        title: "Planner Contacts",
        users: users.select { |user| user.planner? && user.contact? }
      }
    ]

    if @show_clients
      groups << {
        id: "clients",
        title: "Clients",
        users: users.select(&:client?)
      }
    end

    groups
  end

  def access_type_for_user(user)
    return "admin" if user.admin?
    return "client" if user.client?
    return "planner_contact" if user.planner? && user.contact?

    "planner"
  end

  def access_type_label_for_user(user)
    ACCESS_TYPE_LABELS.fetch(access_type_for_user(user))
  end

  def access_type_options_for_roles(role_options)
    allowed_roles = Array(role_options).map(&:to_s)

    ACCESS_TYPE_ATTRIBUTES.filter_map do |access_type, attributes|
      next unless allowed_roles.include?(attributes[:role])

      [ACCESS_TYPE_LABELS.fetch(access_type), access_type]
    end
  end
end
