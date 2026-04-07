module Events
  class EventGuestsController < ApplicationController
    before_action :set_event
    before_action :set_event_guest, only: %i[update destroy move_up move_down]

    def create
      @event_guest = @event.event_guests.new(event_guest_params.merge(kind: EventGuest::KINDS[:key_person]))

      if @event_guest.save
        redirect_to safe_return_to(fallback: event_people_path(@event)), notice: "Key person saved."
      else
        redirect_to safe_return_to(fallback: event_people_path(@event)), alert: @event_guest.errors.full_messages.to_sentence
      end
    end

    def update
      if @event_guest.update(event_guest_params)
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
      @event = Event.find(params[:event_id])
    end

    def set_event_guest
      @event_guest = @event.event_guests.find(params[:id])
    end

    def event_guest_params
      permitted = params.require(:event_guest).permit(
        :first_name,
        :last_name,
        :relationship,
        :vip,
        :group_name,
        :custom_group_name
      )
      custom_group_name = permitted.delete(:custom_group_name).to_s.strip.presence
      permitted[:group_name] = custom_group_name || permitted[:group_name]
      permitted
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
  end
end
