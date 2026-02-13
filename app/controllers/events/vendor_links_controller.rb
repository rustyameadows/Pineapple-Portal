module Events
  class VendorLinksController < ApplicationController
    before_action :set_event

    def ensure
      global_vendor = resolve_global_vendor
      unless global_vendor
        render json: { error: "Vendor not found" }, status: :not_found
        return
      end

      event_vendor = @event.event_vendors.find_or_create_by!(global_vendor_id: global_vendor.id) do |row|
        row.name = global_vendor.name
        row.client_visible = true
      end

      render json: {
        linked: true,
        global_vendor_id: global_vendor.id,
        event_vendor_id: event_vendor.id,
        name: global_vendor.name
      }
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def resolve_global_vendor
      if params[:global_vendor_id].present?
        GlobalVendor.find_by(id: params[:global_vendor_id])
      elsif params[:name].present?
        GlobalVendor.find_by(normalized_name: GlobalVendor.normalize_name(params[:name]))
      end
    end
  end
end
