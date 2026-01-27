module Events
  class EventLinksController < ApplicationController
    before_action :set_event
    before_action :set_event_link, only: %i[update destroy move_up move_down]

    def create
      @event_link = @event.event_links.new(event_link_params)

      if @event_link.save
        unless persist_planning_tokens_for(@event_link)
          redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event)), alert: @event.errors.full_messages.to_sentence and return
        end
        redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event)), notice: "Quick link added."
      else
        redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event)), alert: @event_link.errors.full_messages.to_sentence
      end
    end

    def update
      if @event_link.update(event_link_params)
        unless persist_planning_tokens_for(@event_link)
          redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event)), alert: @event.errors.full_messages.to_sentence and return
        end
        redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event)), notice: "Quick link updated."
      else
        redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event)), alert: @event_link.errors.full_messages.to_sentence
      end
    end

    def destroy
      token = planning_link_token_for(@event_link)
      @event_link.destroy
      unless remove_planning_token(token)
        redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event)), alert: @event.errors.full_messages.to_sentence and return
      end
      redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event)), notice: "Quick link removed."
    end

    def move_up
      move_link(:up)
    end

    def move_down
      move_link(:down)
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_event_link
      @event_link = @event.event_links.find(params[:id])
    end

    def event_link_params
      params.require(:event_link).permit(:label, :url, :link_type, :financial_only)
    end

    def move_link(direction)
      offset = direction == :up ? -1 : 1
      target_position = @event_link.position + offset

      sibling = @event.event_links.find_by(position: target_position, link_type: @event_link.link_type)

      if sibling
        EventLink.transaction do
          sibling.update!(position: @event_link.position)
          @event_link.update!(position: target_position)
        end
      end

      redirect_to safe_return_to(fallback: client_portal_event_settings_path(@event))
    end

    def persist_planning_tokens_for(event_link)
      return true unless event_link.link_type == "planning"

      @event.append_planning_event_link_token(event_link)
      return true unless @event.changed?

      @event.save
    end

    def planning_link_token_for(event_link)
      return unless event_link.link_type == "planning"

      Event::PlanningLinkToken.event_link(event_link.id)
    end

    def remove_planning_token(token)
      return true if token.blank?

      tokens = @event.planning_link_tokens.reject { |existing| existing == token }
      @event.planning_link_tokens = tokens
      return true unless @event.changed?

      @event.save
    end
  end
end
