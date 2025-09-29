module Events
  class EventVendorsController < ApplicationController
    before_action :set_event
    before_action :set_event_vendor, only: %i[update destroy move_up move_down]

    def create
      @event_vendor = @event.event_vendors.new(event_vendor_params)

      if @event_vendor.save
        redirect_back fallback_location: vendors_event_settings_path(@event), notice: "Vendor saved."
      else
        redirect_back fallback_location: vendors_event_settings_path(@event), alert: @event_vendor.errors.full_messages.to_sentence
      end
    end

    def update
      if @event_vendor.update(event_vendor_params)
        redirect_back fallback_location: vendors_event_settings_path(@event), notice: "Vendor updated."
      else
        redirect_back fallback_location: vendors_event_settings_path(@event), alert: @event_vendor.errors.full_messages.to_sentence
      end
    end

    def destroy
      @event_vendor.destroy
      redirect_back fallback_location: vendors_event_settings_path(@event), notice: "Vendor removed."
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

    def set_event_vendor
      @event_vendor = @event.event_vendors.find(params[:id])
    end

    def event_vendor_params
      params.require(:event_vendor).permit(:name, :vendor_type, :social_handle, :client_visible, :position, contacts_attributes: %i[id name title email phone notes _destroy])
    end

    def move_record(direction)
      ordered = @event.event_vendors.order(:position, :id).to_a
      current_index = ordered.index(@event_vendor)
      return unless current_index

      sibling_index = direction == :up ? current_index - 1 : current_index + 1
      sibling = ordered[sibling_index]

      if sibling
        EventVendor.transaction do
          current_position = @event_vendor.position
          @event_vendor.update!(position: sibling.position)
          sibling.update!(position: current_position)
        end
      end

      redirect_back fallback_location: vendors_event_settings_path(@event)
    end
  end
end
