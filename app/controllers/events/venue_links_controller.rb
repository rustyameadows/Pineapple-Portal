module Events
  class VenueLinksController < ApplicationController
    before_action :set_event

    def ensure
      global_venue = resolve_global_venue
      unless global_venue
        render json: { error: "Venue not found" }, status: :not_found
        return
      end

      event_venue = @event.event_venues.find_or_create_by!(global_venue_id: global_venue.id) do |row|
        row.name = global_venue.name
        row.client_visible = true
      end

      render json: {
        linked: true,
        global_venue_id: global_venue.id,
        event_venue_id: event_venue.id,
        name: global_venue.name
      }
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end

    def resolve_global_venue
      if params[:global_venue_id].present?
        GlobalVenue.find_by(id: params[:global_venue_id])
      elsif params[:name].present?
        GlobalVenue.find_by(normalized_name: GlobalVenue.normalize_name(params[:name]))
      end
    end
  end
end
