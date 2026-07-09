module Events
  class EventVenuesController < ApplicationController
    before_action :set_event
    before_action :set_event_venue, only: %i[update destroy move_up move_down]

    def create
      attrs = event_venue_params
      resolved_global_venue = resolve_global_venue
      attrs[:global_venue_id] = resolved_global_venue&.id
      @event_venue = @event.event_venues.new(attrs)
      existing = existing_venue_for(@event_venue.global_venue_id)
      if existing
        redirect_to safe_return_to(fallback: locations_event_settings_path(@event)), notice: "Location already added to this event."
        return
      end

      if @event_venue.save
        sync_global_venue_from_event(@event_venue)
        redirect_to safe_return_to(fallback: locations_event_settings_path(@event)), notice: "Location saved."
      else
        redirect_to safe_return_to(fallback: locations_event_settings_path(@event)), alert: @event_venue.errors.full_messages.to_sentence
      end
    end

    def update
      attrs = event_venue_params
      resolved_global_venue = resolve_global_venue
      attrs[:global_venue_id] = resolved_global_venue&.id
      existing = existing_venue_for(attrs[:global_venue_id], excluding_id: @event_venue.id)
      if existing
        redirect_to safe_return_to(fallback: locations_event_settings_path(@event)), alert: "Location already added to this event."
        return
      end

      if @event_venue.update(attrs)
        sync_global_venue_from_event(@event_venue)
        redirect_to safe_return_to(fallback: locations_event_settings_path(@event)), notice: "Location updated."
      else
        redirect_to safe_return_to(fallback: locations_event_settings_path(@event)), alert: @event_venue.errors.full_messages.to_sentence
      end
    end

    def destroy
      @event_venue.destroy
      redirect_to safe_return_to(fallback: locations_event_settings_path(@event)), notice: "Location removed."
    end

    def move_up
      move_record(:up)
    end

    def move_down
      move_record(:down)
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end

    def set_event_venue
      @event_venue = @event.event_venues.find(params[:id])
    end

    def event_venue_params
      params.require(:event_venue).permit(
        :name,
        :address,
        :client_visible,
        :position,
        :global_venue_id,
        contacts_attributes: %i[id name title email phone notes _destroy]
      )
    end

    def resolve_global_venue
      if params.dig(:event_venue, :global_venue_id).present?
        GlobalVenue.find_by(id: params[:event_venue][:global_venue_id])
      else
        find_or_create_global_venue(params.dig(:event_venue, :name))
      end
    end

    def existing_venue_for(global_venue_id, excluding_id: nil)
      return nil if global_venue_id.blank?

      scope = @event.event_venues.where(global_venue_id: global_venue_id)
      scope = scope.where.not(id: excluding_id) if excluding_id.present?
      scope.first
    end

    def find_or_create_global_venue(raw_name)
      name = raw_name.to_s.strip
      return nil if name.blank?

      normalized_name = GlobalVenue.normalize_name(name)
      GlobalVenue.find_by(normalized_name: normalized_name) || GlobalVenue.create!(name: name)
    rescue ActiveRecord::RecordNotUnique
      GlobalVenue.find_by(normalized_name: normalized_name)
    end

    def sync_global_venue_from_event(record)
      return unless record.global_venue

      updates = {
        contacts_attributes: record.contacts_attributes
      }

      record.global_venue.update(updates)
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

      redirect_to safe_return_to(fallback: locations_event_settings_path(@event))
    end
  end
end
