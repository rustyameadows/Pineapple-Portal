module Events
  class EventGuestsController < ApplicationController
    before_action :set_event
    before_action :set_event_guest, only: %i[update destroy move_up move_down]

    def create
      @event_guest = @event.event_guests.new(kind: EventGuest::KINDS[:key_person])

      if persist_event_guest(@event_guest)
        redirect_to safe_return_to(fallback: event_people_path(@event)), notice: "Key person saved."
      else
        redirect_to safe_return_to(fallback: event_people_path(@event)), alert: @event_guest.errors.full_messages.to_sentence
      end
    end

    def update
      if persist_event_guest(@event_guest)
        redirect_to safe_return_to(fallback: event_people_path(@event)), notice: "Key person updated."
      else
        redirect_to safe_return_to(fallback: event_people_path(@event)), alert: @event_guest.errors.full_messages.to_sentence
      end
    end

    def destroy
      @event_guest.destroy
      redirect_to safe_return_to(fallback: event_people_path(@event)), notice: "Key person removed."
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

    def set_event_guest
      @event_guest = @event.event_guests.find(params[:id])
    end

    def event_guest_params
      params.require(:event_guest).permit(
        :first_name,
        :last_name,
        :relationship,
        :vip,
        :event_key_person_group_id,
        :group_name,
        :custom_group_name
      )
    end

    def move_record(direction)
      ordered = @event.event_guests.key_people.order(:position, :id).to_a
      current_index = ordered.index(@event_guest)
      return unless current_index

      sibling_index = direction == :up ? current_index - 1 : current_index + 1
      sibling = ordered[sibling_index]

      if sibling
        EventGuest.transaction do
          current_position = @event_guest.position
          @event_guest.update!(position: sibling.position)
          sibling.update!(position: current_position)
        end
      end

      redirect_to safe_return_to(fallback: event_people_path(@event))
    end

    def persist_event_guest(event_guest)
      saved = false

      EventGuest.transaction do
        assign_event_guest_attributes(event_guest)
        saved = event_guest.save
        raise ActiveRecord::Rollback unless saved
      end

      saved
    end

    def assign_event_guest_attributes(event_guest)
      permitted = event_guest_params
      event_guest.assign_attributes(
        permitted.except(:event_key_person_group_id, :group_name, :custom_group_name)
      )

      group = resolve_key_person_group(permitted)
      if group
        event_guest.event_key_person_group = group
        event_guest.group_name = group.name
      else
        event_guest.event_key_person_group = nil if event_guest.key_person?
        event_guest.errors.add(:event_key_person_group, "must be selected") if event_guest.key_person?
      end
    end

    def resolve_key_person_group(permitted)
      custom_group_name = permitted[:custom_group_name].to_s.strip.presence
      return @event.ensure_key_person_group!(custom_group_name) if custom_group_name

      selected_group = permitted[:event_key_person_group_id].to_s.strip.presence
      legacy_group_name = permitted[:group_name].to_s.strip.presence
      selected_value = selected_group == "__new__" ? nil : selected_group

      if selected_value.present?
        group = @event.event_key_person_groups.find_by(id: selected_value)
        return group if group

        @event_guest.errors.add(:event_key_person_group, "is invalid")
        return nil
      end

      return nil if legacy_group_name == "__new__"
      return nil if legacy_group_name.blank?

      @event.event_key_person_groups.find_by("LOWER(name) = ?", legacy_group_name.downcase) ||
        @event.ensure_key_person_group!(legacy_group_name)
    end
  end
end
