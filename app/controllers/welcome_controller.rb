class WelcomeController < ApplicationController
  def home
    if User.none?
      redirect_to new_user_path and return
    end

    @events = accessible_events_scope.active
                   .order(Arel.sql("COALESCE(events.starts_on, events.updated_at, events.created_at) ASC"))
  end
end
