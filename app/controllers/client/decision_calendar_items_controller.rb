module Client
  class DecisionCalendarItemsController < PortalController
    before_action :set_event
    before_action :set_calendar
    before_action :set_item

    def show
      respond_to do |format|
        format.json { render json: { calendar_item: decision_item_payload(@item) } }
        format.html { redirect_to client_event_calendar_path(@event, "decision-calendar") }
      end
    end

    def update
      if @item.update(decision_item_params)
        redirect_to client_event_calendar_path(@event, "decision-calendar"), notice: "Decision updated."
      else
        flash[:alert] = @item.errors.full_messages.to_sentence
        redirect_to client_event_calendar_path(@event, "decision-calendar"), status: :see_other
      end
    end

    private

    def set_event
      @event = Event.find(params[:event_id])
    end

    def set_calendar
      @calendar = @event.run_of_show_calendar
      head :not_found unless @calendar
    end

    def set_item
      @item = @calendar.calendar_items.find(params[:id])
    end

    def decision_item_params
      params.require(:calendar_item).permit(:title, :status, :vendor_name, :notes)
    end

    def decision_item_payload(item)
      {
        id: item.id,
        title: item.title,
        status: item.status,
        vendor_name: item.vendor_name,
        notes: item.notes
      }
    end
  end
end
