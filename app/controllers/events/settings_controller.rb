module Events
  class SettingsController < ApplicationController
    before_action :set_event

    def show; end

    def team; end

    def notifications; end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end
  end
end
