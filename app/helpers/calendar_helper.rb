module CalendarHelper
  def calendar_item_time_label(item, timezone)
    start_time = item.effective_starts_at&.in_time_zone(timezone)
    finish_time = item.effective_ends_at&.in_time_zone(timezone)

    if start_time
      if finish_time && !item.all_day?
        "#{format_time_or_date(start_time)} – #{format_time_only(finish_time)}"
      else
        format_time_or_date(start_time)
      end
    else
      calendar_item_relative_label(item) || "Exact time coming soon"
    end
  end

  def calendar_item_end_label(item, timezone)
    finish_time = item.effective_ends_at&.in_time_zone(timezone)
    finish_time && format_time_or_date(finish_time)
  end

  def calendar_item_relative_label(item)
    return unless item.relative? && item.relative_anchor

    anchor_name = item.relative_anchor.title
    minutes = item.relative_offset_minutes.to_i.abs

    if minutes.zero?
      basis = item.relative_to_anchor_end? ? "end" : "start"
      "Anchored to #{anchor_name} #{basis}"
    else
      direction = item.relative_before? ? "before" : "after"
      suffix = item.relative_to_anchor_end? ? "#{anchor_name} ends" : anchor_name
      "#{minutes} min #{direction} #{suffix}"
    end
  end

  def calendar_item_duration_label(item)
    return "All day" if item.all_day?

    item.duration_minutes.present? ? "#{item.duration_minutes} min" : "—"
  end

  def calendar_item_tags_label(item)
    names = item.event_calendar_tags.map(&:name).reject(&:blank?)
    names.any? ? names.join(', ') : "—"
  end

  def calendar_tag_style(tag)
    color = tag.color_token.to_s.strip
    return nil if color.blank?

    styles = ["--tag-color: #{color}"]
    styles << "--tag-text-color: #{contrasting_text_color(color)}" if hex_color?(color)
    styles.join('; ')
  end

  private

  def hex_color?(value)
    value.match?(/\A#(?:[0-9a-fA-F]{3}){1,2}\z/)
  end

  def contrasting_text_color(hex)
    rgb = hex.delete('#')
    rgb = rgb.chars.map { |c| c * 2 }.join if rgb.length == 3
    r = rgb[0..1].to_i(16)
    g = rgb[2..3].to_i(16)
    b = rgb[4..5].to_i(16)

    luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
    luminance > 0.6 ? '#111827' : '#ffffff'
  end

  def format_time_or_date(time)
    return time.strftime("%b %-d") if midnight?(time)

    time.strftime("%b %-d • %l:%M %p")
  end

  def format_time_only(time)
    return time.strftime("%b %-d") if midnight?(time)

    time.strftime("%l:%M %p").strip
  end

  def midnight?(time)
    time.strftime("%H:%M") == "00:00"
  end
end
