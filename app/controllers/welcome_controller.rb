class WelcomeController < ApplicationController
  def home
    @users = User.order(created_at: :desc)
  end
end
