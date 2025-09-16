class WelcomeController < ApplicationController
  def home
    @users = User.order(created_at: :desc)
    @user = User.new
  end
end
