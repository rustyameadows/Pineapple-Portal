module Events
  class PlanningLinksController < ApplicationController
    before_action :set_event

    def toggle
      key = params[:id].to_s

      unless ClientPortal::PlanningLinks.built_in_keys.include?(key)
        redirect_back fallback_location: client_portal_event_settings_path(@event), alert: "Unknown planning link." and return
      end

      message = if @event.planning_link_enabled?(key)
                  @event.disable_planning_link(key)
                  "Planning link hidden."
                else
                  @event.enable_planning_link(key)
                  "Planning link enabled."
                end

      if @event.save
        redirect_back fallback_location: client_portal_event_settings_path(@event), notice: message
      else
        @event.reload
        redirect_back fallback_location: client_portal_event_settings_path(@event), alert: @event.errors.full_messages.to_sentence
      end
    end

    def move_up
      reorder_token(:up)
    end

    def move_down
      reorder_token(:down)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def reorder_token(direction)
      token = params[:id].to_s

      unless planning_token_permitted?(token)
        redirect_back fallback_location: client_portal_event_settings_path(@event), alert: "Unknown planning link." and return
      end

      if @event.move_planning_link_token(token, direction)
        if @event.save
          redirect_back fallback_location: client_portal_event_settings_path(@event), notice: "Planning link order updated."
        else
          @event.reload
          redirect_back fallback_location: client_portal_event_settings_path(@event), alert: @event.errors.full_messages.to_sentence
        end
      else
        redirect_back fallback_location: client_portal_event_settings_path(@event), notice: "Planning link already at edge of list."
      end
    end

    def planning_token_permitted?(token)
      Event::PlanningLinkToken.valid?(token, event: @event) && @event.planning_link_tokens.include?(token)
    end
  end
end
