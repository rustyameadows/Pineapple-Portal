module Events
  class EventKeyPersonGroupsController < ApplicationController
    before_action :set_event
    before_action :set_group

    def update
      if @group.update(group_params)
        redirect_to safe_return_to(fallback: event_people_path(@event)), notice: "Group updated."
      else
        redirect_to safe_return_to(fallback: event_people_path(@event)), alert: @group.errors.full_messages.to_sentence
      end
    end

    private

    def set_event
      @event = find_accessible_event!(params[:event_id])
    end

    def set_group
      @group = @event.event_key_person_groups.find(params[:id])
    end

    def group_params
      params.require(:event_key_person_group).permit(:name)
    end
  end
end
