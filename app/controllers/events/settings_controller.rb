module Events
  class SettingsController < ApplicationController
    include EventsSettingsPageSupport

    before_action :set_event
    helper CalendarHelper

    def show
      prepare_general_settings
    end

    def client_portal
      prepare_client_portal_settings
    end

    def clients
      prepare_client_team
    end

    def vendors
      prepare_vendors
    end

    def locations
      prepare_locations
    end

    def planners
      prepare_planner_team
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end
  end
end
