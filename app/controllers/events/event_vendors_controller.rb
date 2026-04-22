module Events
  class EventVendorsController < ApplicationController
    before_action :set_event
    before_action :set_event_vendor, only: %i[update destroy move_up move_down]

    def create
      attrs = event_vendor_params
      resolved_global_vendor = resolve_global_vendor
      attrs[:global_vendor_id] = resolved_global_vendor&.id
      @event_vendor = @event.event_vendors.new(attrs)
      existing = existing_vendor_for(@event_vendor.global_vendor_id)
      if existing
        redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), notice: "Vendor already added to this event."
        return
      end

      if @event_vendor.save
        sync_global_vendor_from_event(@event_vendor)
        redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), notice: "Vendor saved."
      else
        redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), alert: @event_vendor.errors.full_messages.to_sentence
      end
    end

    def update
      attrs = event_vendor_params
      resolved_global_vendor = resolve_global_vendor
      attrs[:global_vendor_id] = resolved_global_vendor&.id
      existing = existing_vendor_for(attrs[:global_vendor_id], excluding_id: @event_vendor.id)
      if existing
        redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), alert: "Vendor already added to this event."
        return
      end

      if @event_vendor.update(attrs)
        sync_global_vendor_from_event(@event_vendor)
        redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), notice: "Vendor updated."
      else
        redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), alert: @event_vendor.errors.full_messages.to_sentence
      end
    end

    def destroy
      @event_vendor.destroy
      redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), notice: "Vendor removed."
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
      params.require(:event_vendor).permit(
        :name,
        :vendor_type,
        :social_handle,
        :team_meals,
        :client_visible,
        :position,
        :global_vendor_id,
        contacts_attributes: %i[id name title email phone notes _destroy]
      )
    end

    def resolve_global_vendor
      if params.dig(:event_vendor, :global_vendor_id).present?
        GlobalVendor.find_by(id: params[:event_vendor][:global_vendor_id])
      else
        find_or_create_global_vendor(params.dig(:event_vendor, :name))
      end
    end

    def existing_vendor_for(global_vendor_id, excluding_id: nil)
      return nil if global_vendor_id.blank?

      scope = @event.event_vendors.where(global_vendor_id: global_vendor_id)
      scope = scope.where.not(id: excluding_id) if excluding_id.present?
      scope.first
    end

    def find_or_create_global_vendor(raw_name)
      name = raw_name.to_s.strip
      return nil if name.blank?

      normalized_name = GlobalVendor.normalize_name(name)
      GlobalVendor.find_by(normalized_name: normalized_name) || GlobalVendor.create!(name: name)
    rescue ActiveRecord::RecordNotUnique
      GlobalVendor.find_by(normalized_name: normalized_name)
    end

    def sync_global_vendor_from_event(record)
      return unless record.global_vendor

      updates = {}
      updates[:default_vendor_type] = record.vendor_type if record.vendor_type.present?
      updates[:default_social_handle] = record.social_handle if record.social_handle.present?
      updates[:contacts_attributes] = record.contacts_attributes

      record.global_vendor.update(updates) if updates.any?
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

      redirect_to safe_return_to(fallback: vendors_event_settings_path(@event))
    end
  end
end
