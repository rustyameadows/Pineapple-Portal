module Events
  class VenueOptionsController < ApplicationController
    before_action :set_event

    def index
      results = Venues::OptionSearch.new(
        event: @event,
        query: params[:q],
        limit: params[:limit]
      ).call

      render json: {
        options: results.map do |result|
          {
            id: result.global_venue.id,
            name: result.global_venue.name,
            is_active_on_event: result.is_active_on_event,
            usage_count: result.usage_count,
            matched_by: result.matched_by,
            score: result.score
          }
        end
      }
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end
  end
end
