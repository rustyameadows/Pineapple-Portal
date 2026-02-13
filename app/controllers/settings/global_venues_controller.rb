module Settings
  class GlobalVenuesController < ApplicationController
    before_action :set_global_venue, only: %i[update destroy]

    def index
      @global_venue = GlobalVenue.new
      @global_venues = GlobalVenue
                       .left_joins(:event_venues)
                       .select("global_venues.*, COUNT(event_venues.id) AS usage_count")
                       .group("global_venues.id")
                       .order(Arel.sql("LOWER(global_venues.name) ASC"), :id)
    end

    def create
      @global_venue = GlobalVenue.new(global_venue_params)

      if @global_venue.save
        redirect_to settings_global_venues_path, notice: "Global venue created."
      else
        redirect_to settings_global_venues_path, alert: @global_venue.errors.full_messages.to_sentence
      end
    end

    def update
      if @global_venue.update(global_venue_params)
        redirect_to settings_global_venues_path, notice: "Global venue updated."
      else
        redirect_to settings_global_venues_path, alert: @global_venue.errors.full_messages.to_sentence
      end
    end

    def destroy
      if @global_venue.event_venues.exists?
        redirect_to settings_global_venues_path, alert: "Cannot delete a global venue that is linked to events."
        return
      end

      @global_venue.destroy
      redirect_to settings_global_venues_path, notice: "Global venue removed."
    end

    private

    def set_global_venue
      @global_venue = GlobalVenue.find(params[:id])
    end

    def global_venue_params
      params.require(:global_venue).permit(
        :name,
        contacts_attributes: %i[id name title email phone notes _destroy]
      )
    end
  end
end
