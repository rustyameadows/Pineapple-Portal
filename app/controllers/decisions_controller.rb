class DecisionsController < ApplicationController
  helper CalendarHelper

  DECISION_TAG_NAME = "decisions".freeze
  BULK_STATUS_CHOICES = CalendarItem::STATUSES.values_at(:planned, :in_progress, :completed).freeze

  def index
    @items = ordered_decision_items
    @decision_views_by_event_id = ensure_decision_views(@items)
  end

  def bulk_update
    status = bulk_params[:status].to_s
    unless bulk_params[:bulk_action].to_s == "set_status" && BULK_STATUS_CHOICES.include?(status)
      redirect_to safe_return_to(fallback: decisions_path), alert: "Select a valid decision status."
      return
    end

    selected_items = decision_items_scope.where(id: selected_item_ids)
    if selected_items.empty?
      redirect_to safe_return_to(fallback: decisions_path), alert: "Select at least one decision."
      return
    end

    count = 0
    CalendarItem.transaction do
      selected_items.find_each do |item|
        item.update!(status:)
        count += 1
      end
    end

    redirect_to safe_return_to(fallback: decisions_path),
                notice: "Status updated for #{count} decision#{'s' unless count == 1}."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to safe_return_to(fallback: decisions_path),
                alert: e.record.errors.full_messages.to_sentence.presence || "Unable to update selected decisions."
  end

  private

  def ordered_decision_items
    decision_items_scope
      .includes(:event_calendar_tags, :team_members, :relative_anchor, event_calendar: [:event, :event_calendar_views])
      .to_a
      .sort_by do |item|
        event = item.event_calendar.event
        [
          item.effective_starts_at || Time.zone.local(9999, 12, 31),
          event.name.to_s.downcase,
          item.title.to_s.downcase,
          item.id
        ]
      end
  end

  def decision_items_scope
    CalendarItem
      .joins(:event_calendar_tags, event_calendar: :event)
      .where(event_calendars: { kind: EventCalendar::KINDS[:master] })
      .where(events: { archived_at: nil })
      .where("LOWER(event_calendar_tags.name) = ?", DECISION_TAG_NAME)
      .distinct
  end

  def selected_item_ids
    Array(params[:item_ids]).map(&:to_i).reject(&:zero?)
  end

  def bulk_params
    params.fetch(:bulk, {}).permit(:bulk_action, :status)
  end

  def ensure_decision_views(items)
    items
      .map { |item| item.event_calendar.event }
      .uniq
      .each_with_object({}) do |event, views_by_event_id|
        views_by_event_id[event.id] = Documents::Generated::DefaultTimelineViews.ensure_view!(event, "Decision Calendar")
      end
  end
end
