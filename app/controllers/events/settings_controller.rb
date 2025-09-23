module Events
  class SettingsController < ApplicationController
    before_action :set_event

    def show
      @event_link = @event.event_links.new
      @event_links = @event.event_links.ordered
    end

    def team; end

    def notifications; end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
