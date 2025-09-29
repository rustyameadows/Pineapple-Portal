module Events
  class EventLinksController < ApplicationController
    before_action :set_event
    before_action :set_event_link, only: %i[update destroy move_up move_down]

    def create
      @event_link = @event.event_links.new(event_link_params)

      if @event_link.save
        redirect_back fallback_location: client_portal_event_settings_path(@event), notice: "Quick link added."
      else
        redirect_back fallback_location: client_portal_event_settings_path(@event), alert: @event_link.errors.full_messages.to_sentence
      end
    end

    def update
      if @event_link.update(event_link_params)
        redirect_back fallback_location: client_portal_event_settings_path(@event), notice: "Quick link updated."
      else
        redirect_back fallback_location: client_portal_event_settings_path(@event), alert: @event_link.errors.full_messages.to_sentence
      end
    end

    def destroy
      @event_link.destroy
      redirect_back fallback_location: client_portal_event_settings_path(@event), notice: "Quick link removed."
    end

    def move_up
      move_link(:up)
    end

    def move_down
      move_link(:down)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_event_link
      @event_link = @event.event_links.find(params[:id])
    end

    def event_link_params
      params.require(:event_link).permit(:label, :url)
    end

    def move_link(direction)
      offset = direction == :up ? -1 : 1
      target_position = @event_link.position + offset

      sibling = @event.event_links.find_by(position: target_position)

      if sibling
        EventLink.transaction do
          sibling.update!(position: @event_link.position)
          @event_link.update!(position: target_position)
        end
      end

      redirect_back fallback_location: client_portal_event_settings_path(@event)
    end
  end
end
