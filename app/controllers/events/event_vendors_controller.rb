module Events
  class EventVendorsController < ApplicationController
    before_action :set_event
    before_action :set_event_vendor, only: %i[update destroy move_up move_down]

    def create
      duplicate_vendor = false

      EventVendor.transaction do
        resolved_global_vendor = resolve_global_vendor
        unless resolved_global_vendor
          @event_vendor = @event.event_vendors.new(event_vendor_create_attributes)
          @event_vendor.errors.add(:global_vendor, "must be selected from the global library or explicitly created")
          raise ActiveRecord::RecordInvalid.new(@event_vendor)
        end

        existing = existing_vendor_for(resolved_global_vendor.id)
        if existing
          duplicate_vendor = true
          next
        end

        @event_vendor = @event.event_vendors.create!(
          event_vendor_create_attributes.merge(global_vendor: resolved_global_vendor)
        )
        contact_ids = if contact_selection_submitted?
                        submitted_contact_ids
        else
                        resolved_global_vendor.contact_ids
        end
        @event_vendor.replace_contact_ids!(contact_ids)
      end

      notice = duplicate_vendor ? "Vendor already added to this event." : "Vendor saved."
      redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), notice:
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => e
      redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), alert: event_vendor_error_message(e)
    end

    def update
      EventVendor.transaction do
        @event_vendor.update!(event_vendor_update_attributes)
        @event_vendor.replace_contact_ids!(submitted_contact_ids) if contact_selection_submitted?
      end

      redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), notice: "Vendor updated."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound, ArgumentError => e
      redirect_to safe_return_to(fallback: vendors_event_settings_path(@event)), alert: event_vendor_error_message(e)
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
      @event = find_accessible_event!(params[:event_id])
    end

    def set_event_vendor
      @event_vendor = @event.event_vendors.find(params[:id])
    end

    def event_vendor_create_params
      params.require(:event_vendor).permit(
        :name,
        :vendor_type,
        :team_meals,
        :client_visible,
        :position,
        :global_vendor_id,
        :create_global_vendor,
        global_vendor_contact_ids: []
      )
    end

    def event_vendor_update_params
      params.require(:event_vendor).permit(
        :vendor_type,
        :team_meals,
        :client_visible,
        :position,
        global_vendor_contact_ids: []
      )
    end

    def event_vendor_create_attributes
      event_vendor_create_params.except(:create_global_vendor, :global_vendor_contact_ids, :global_vendor_id)
    end

    def event_vendor_update_attributes
      event_vendor_update_params.except(:global_vendor_contact_ids)
    end

    def resolve_global_vendor
      if event_vendor_create_params[:global_vendor_id].present?
        GlobalVendor.find_by(id: event_vendor_create_params[:global_vendor_id])
      elsif ActiveModel::Type::Boolean.new.cast(event_vendor_create_params[:create_global_vendor])
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

    def contact_selection_submitted?
      params.dig(:event_vendor, :global_vendor_contact_ids).present? ||
        params.fetch(:event_vendor, {}).key?(:global_vendor_contact_ids)
    end

    def submitted_contact_ids
      Array(params.dig(:event_vendor, :global_vendor_contact_ids)).reject(&:blank?)
    end

    def event_vendor_error_message(error)
      return error.record.errors.full_messages.to_sentence if error.respond_to?(:record) && error.record

      error.message
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
