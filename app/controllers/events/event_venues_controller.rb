module Events
  class EventVenuesController < ApplicationController
    before_action :set_event
    before_action :set_event_venue, only: %i[update destroy move_up move_down]

    def create
      @event_venue = @event.event_venues.new(event_venue_params)

      if @event_venue.save
        redirect_back fallback_location: locations_event_settings_path(@event), notice: "Location saved."
      else
        redirect_back fallback_location: locations_event_settings_path(@event), alert: @event_venue.errors.full_messages.to_sentence
      end
    end

    def update
      if @event_venue.update(event_venue_params)
        redirect_back fallback_location: locations_event_settings_path(@event), notice: "Location updated."
      else
        redirect_back fallback_location: locations_event_settings_path(@event), alert: @event_venue.errors.full_messages.to_sentence
      end
    end

    def destroy
      @event_venue.destroy
      redirect_back fallback_location: locations_event_settings_path(@event), notice: "Location removed."
    end

    def move_up
      move_record(:up)
    end

    def move_down
      move_record(:down)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_event_venue
      @event_venue = @event.event_venues.find(params[:id])
    end

    def event_venue_params
      params.require(:event_venue).permit(:name, :client_visible, :position, contacts_attributes: %i[id name title email phone notes _destroy])
    end

    def move_record(direction)
      ordered = @event.event_venues.order(:position, :id).to_a
      current_index = ordered.index(@event_venue)
      return unless current_index

      sibling_index = direction == :up ? current_index - 1 : current_index + 1
      sibling = ordered[sibling_index]

      if sibling
        EventVenue.transaction do
          current_position = @event_venue.position
          @event_venue.update!(position: sibling.position)
          sibling.update!(position: current_position)
        end
      end

      redirect_back fallback_location: locations_event_settings_path(@event)
    end
  end
end
