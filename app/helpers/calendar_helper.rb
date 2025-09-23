module CalendarHelper
  def calendar_item_time_label(item, timezone)
    start_time = item.effective_starts_at&.in_time_zone(timezone)
    return start_time.strftime("%b %-d • %l:%M %p") if start_time

    calendar_item_relative_label(item) || "Exact time coming soon"
  end

  def calendar_item_relative_label(item)
    return unless item.relative? && item.relative_anchor

    anchor_name = item.relative_anchor.title
    minutes = item.relative_offset_minutes.to_i.abs

    if minutes.zero?
      "Anchored to #{anchor_name}"
    else
      direction = item.relative_before? ? "before" : "after"
      "#{minutes} min #{direction} #{anchor_name}"
    end
  end

  def calendar_item_duration_label(item)
    item.duration_minutes.present? ? "#{item.duration_minutes} min" : "—"
  end

  def calendar_item_tags_label(item)
    names = item.event_calendar_tags.map(&:name).reject(&:blank?)
    names.any? ? names.join(', ') : "—"
  end
end
