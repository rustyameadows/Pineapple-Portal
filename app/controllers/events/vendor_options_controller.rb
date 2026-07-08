module Events
  class VendorOptionsController < ApplicationController
    before_action :set_event

    def index
      results = Vendors::OptionSearch.new(
        event: @event,
        query: params[:q],
        limit: params[:limit]
      ).call

      render json: {
        options: results.map do |result|
          {
            id: result.global_vendor.id,
            name: result.global_vendor.name,
            is_active_on_event: result.is_active_on_event,
            usage_count: result.usage_count,
            matched_by: result.matched_by,
            score: result.score,
            vendor_type: result.global_vendor.default_vendor_type,
            social_handle: result.global_vendor.default_social_handle
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
