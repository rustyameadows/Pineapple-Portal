class DecisionsController < ApplicationController
  helper CalendarHelper

  DECISION_TAG_NAME = "decisions".freeze

  def index
    @items = decision_items
    @decision_views_by_event_id = ensure_decision_views(@items)
  end

  private

  def decision_items
    CalendarItem
      .joins(:event_calendar_tags, event_calendar: :event)
      .where(event_calendars: { kind: EventCalendar::KINDS[:master] })
      .where(events: { archived_at: nil })
      .where("LOWER(event_calendar_tags.name) = ?", DECISION_TAG_NAME)
      .includes(:event_calendar_tags, :team_members, :relative_anchor, event_calendar: [:event, :event_calendar_views])
      .distinct
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

  def ensure_decision_views(items)
    items
      .map { |item| item.event_calendar.event }
      .uniq
      .each_with_object({}) do |event, views_by_event_id|
        views_by_event_id[event.id] = Documents::Generated::DefaultTimelineViews.ensure_view!(event, "Decision Calendar")
      end
  end
end
