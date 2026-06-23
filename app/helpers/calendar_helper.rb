module CalendarHelper
  CALENDAR_FILTER_NONE_VALUE = "__none__".freeze
  CSS_NAMED_COLORS = {
    "aliceblue" => "#f0f8ff",
    "antiquewhite" => "#faebd7",
    "aqua" => "#00ffff",
    "aquamarine" => "#7fffd4",
    "azure" => "#f0ffff",
    "beige" => "#f5f5dc",
    "bisque" => "#ffe4c4",
    "black" => "#000000",
    "blanchedalmond" => "#ffebcd",
    "blue" => "#0000ff",
    "blueviolet" => "#8a2be2",
    "brown" => "#a52a2a",
    "burlywood" => "#deb887",
    "cadetblue" => "#5f9ea0",
    "chartreuse" => "#7fff00",
    "chocolate" => "#d2691e",
    "coral" => "#ff7f50",
    "cornflowerblue" => "#6495ed",
    "cornsilk" => "#fff8dc",
    "crimson" => "#dc143c",
    "cyan" => "#00ffff",
    "darkblue" => "#00008b",
    "darkcyan" => "#008b8b",
    "darkgoldenrod" => "#b8860b",
    "darkgray" => "#a9a9a9",
    "darkgreen" => "#006400",
    "darkgrey" => "#a9a9a9",
    "darkkhaki" => "#bdb76b",
    "darkmagenta" => "#8b008b",
    "darkolivegreen" => "#556b2f",
    "darkorange" => "#ff8c00",
    "darkorchid" => "#9932cc",
    "darkred" => "#8b0000",
    "darksalmon" => "#e9967a",
    "darkseagreen" => "#8fbc8f",
    "darkslateblue" => "#483d8b",
    "darkslategray" => "#2f4f4f",
    "darkslategrey" => "#2f4f4f",
    "darkturquoise" => "#00ced1",
    "darkviolet" => "#9400d3",
    "deeppink" => "#ff1493",
    "deepskyblue" => "#00bfff",
    "dimgray" => "#696969",
    "dimgrey" => "#696969",
    "dodgerblue" => "#1e90ff",
    "firebrick" => "#b22222",
    "floralwhite" => "#fffaf0",
    "forestgreen" => "#228b22",
    "fuchsia" => "#ff00ff",
    "gainsboro" => "#dcdcdc",
    "ghostwhite" => "#f8f8ff",
    "gold" => "#ffd700",
    "goldenrod" => "#daa520",
    "gray" => "#808080",
    "green" => "#008000",
    "greenyellow" => "#adff2f",
    "grey" => "#808080",
    "honeydew" => "#f0fff0",
    "hotpink" => "#ff69b4",
    "indianred" => "#cd5c5c",
    "indigo" => "#4b0082",
    "ivory" => "#fffff0",
    "khaki" => "#f0e68c",
    "lavender" => "#e6e6fa",
    "lavenderblush" => "#fff0f5",
    "lawngreen" => "#7cfc00",
    "lemonchiffon" => "#fffacd",
    "lightblue" => "#add8e6",
    "lightcoral" => "#f08080",
    "lightcyan" => "#e0ffff",
    "lightgoldenrodyellow" => "#fafad2",
    "lightgray" => "#d3d3d3",
    "lightgreen" => "#90ee90",
    "lightgrey" => "#d3d3d3",
    "lightpink" => "#ffb6c1",
    "lightsalmon" => "#ffa07a",
    "lightseagreen" => "#20b2aa",
    "lightskyblue" => "#87cefa",
    "lightslategray" => "#778899",
    "lightslategrey" => "#778899",
    "lightsteelblue" => "#b0c4de",
    "lightyellow" => "#ffffe0",
    "lime" => "#00ff00",
    "limegreen" => "#32cd32",
    "linen" => "#faf0e6",
    "magenta" => "#ff00ff",
    "maroon" => "#800000",
    "mediumaquamarine" => "#66cdaa",
    "mediumblue" => "#0000cd",
    "mediumorchid" => "#ba55d3",
    "mediumpurple" => "#9370db",
    "mediumseagreen" => "#3cb371",
    "mediumslateblue" => "#7b68ee",
    "mediumspringgreen" => "#00fa9a",
    "mediumturquoise" => "#48d1cc",
    "mediumvioletred" => "#c71585",
    "midnightblue" => "#191970",
    "mintcream" => "#f5fffa",
    "mistyrose" => "#ffe4e1",
    "moccasin" => "#ffe4b5",
    "navajowhite" => "#ffdead",
    "navy" => "#000080",
    "oldlace" => "#fdf5e6",
    "olive" => "#808000",
    "olivedrab" => "#6b8e23",
    "orange" => "#ffa500",
    "orangered" => "#ff4500",
    "orchid" => "#da70d6",
    "palegoldenrod" => "#eee8aa",
    "palegreen" => "#98fb98",
    "paleturquoise" => "#afeeee",
    "palevioletred" => "#db7093",
    "papayawhip" => "#ffefd5",
    "peachpuff" => "#ffdab9",
    "peru" => "#cd853f",
    "pink" => "#ffc0cb",
    "plum" => "#dda0dd",
    "powderblue" => "#b0e0e6",
    "purple" => "#800080",
    "rebeccapurple" => "#663399",
    "red" => "#ff0000",
    "rosybrown" => "#bc8f8f",
    "royalblue" => "#4169e1",
    "saddlebrown" => "#8b4513",
    "salmon" => "#fa8072",
    "sandybrown" => "#f4a460",
    "seagreen" => "#2e8b57",
    "seashell" => "#fff5ee",
    "sienna" => "#a0522d",
    "silver" => "#c0c0c0",
    "skyblue" => "#87ceeb",
    "slateblue" => "#6a5acd",
    "slategray" => "#708090",
    "slategrey" => "#708090",
    "snow" => "#fffafa",
    "springgreen" => "#00ff7f",
    "steelblue" => "#4682b4",
    "tan" => "#d2b48c",
    "teal" => "#008080",
    "thistle" => "#d8bfd8",
    "tomato" => "#ff6347",
    "turquoise" => "#40e0d0",
    "violet" => "#ee82ee",
    "wheat" => "#f5deb3",
    "white" => "#ffffff",
    "whitesmoke" => "#f5f5f5",
    "yellow" => "#ffff00",
    "yellowgreen" => "#9acd32"
  }.freeze

  def calendar_item_time_label(item, timezone)
    return item.time_caption if item.time_caption.present?

    effective_time_label(item.effective_starts_at, item.effective_ends_at, timezone) ||
      calendar_item_relative_label(item) ||
      "Exact time coming soon"
  end

  def calendar_item_time_only_label(item, timezone)
    return item.time_caption if item.time_caption.present?

    effective_time_only_label(item.effective_starts_at, item.effective_ends_at, timezone) ||
      calendar_item_relative_label(item) ||
      "Exact time coming soon"
  end

  def calendar_item_effective_time_label(item, timezone)
    effective_time_label(item.effective_starts_at, item.effective_ends_at, timezone) || "No computable start time"
  end

  def calendar_item_effective_time_only_label(item, timezone)
    effective_time_only_label(item.effective_starts_at, item.effective_ends_at, timezone) || "No computable start time"
  end

  def calendar_item_time_label_with_marker(item, timezone)
    label = calendar_item_time_label(item, timezone)
    item.relative? ? "#{label}*" : label
  end

  def calendar_item_time_only_label_with_marker(item, timezone)
    label = calendar_item_time_only_label(item, timezone)
    item.relative? ? "#{label}*" : label
  end

  def calendar_item_start_time_only_label(item, timezone)
    start_time = item.effective_starts_at&.in_time_zone(timezone)
    return format_clock_time(start_time) if start_time

    calendar_item_relative_label(item) ||
      item.time_caption.presence ||
      "Exact time coming soon"
  end

  def calendar_item_start_time_only_label_with_marker(item, timezone)
    label = calendar_item_start_time_only_label(item, timezone)
    item.relative? ? "#{label}*" : label
  end

  def calendar_item_day_label(item, timezone)
    start_time = item.effective_starts_at&.in_time_zone(timezone)
    return "Date TBD" unless start_time

    start_time.strftime("%b %-d")
  end

  def calendar_item_day_label_with_marker(item, timezone)
    label = calendar_item_day_label(item, timezone)
    item.relative? ? "#{label}*" : label
  end

  def ros_agent_draft_timezone(task)
    task.event.run_of_show_calendar&.timezone.presence || EventCalendar::DEFAULT_TIMEZONE
  end

  def ros_agent_draft_day_label(day, entries, timezone)
    explicit_date = parse_ros_agent_draft_date(day["date"])
    inferred_date = Array(entries).filter_map { |entry| ros_agent_draft_entry_start_time(entry, timezone) }.first&.to_date
    date = explicit_date || inferred_date

    return date.strftime("%A, %B %-d") if date

    day["label"].presence || "Date TBD"
  end

  def ros_agent_draft_schedule_label(entry, timezone)
    explicit_label = entry["time_label"].presence || entry["time_caption"].presence
    return explicit_label unless explicit_label.blank? || parseable_ros_agent_draft_datetime?(explicit_label)

    start_time = ros_agent_draft_entry_start_time(entry, timezone) || parse_ros_agent_draft_time(explicit_label, timezone)
    finish_time = ros_agent_draft_entry_finish_time(entry, start_time, timezone)
    return effective_time_only_label(start_time, finish_time, timezone) if start_time

    "TBD"
  end

  def ros_agent_draft_entries_for_day(draft, day, timezone)
    nested_entries = Array(day["entries"])
    return nested_entries if nested_entries.present?

    entries = Array(draft["draft_items"])
    draft_days = Array(draft["draft_days"])
    target_date = parse_ros_agent_draft_date(day["date"])
    return entries if target_date.blank? && draft_days.one?

    entries.select do |entry|
      entry_date = ros_agent_draft_entry_start_time(entry, timezone)&.to_date
      entry_date.present? && target_date.present? && entry_date == target_date
    end
  end

  def ros_agent_draft_array_label(values)
    Array(values).map(&:presence).compact.join(", ").presence || "—"
  end

  def ros_agent_draft_source_refs_label(refs)
    Array(refs).map do |ref|
      if ref.is_a?(Hash)
        [ref["artifact"], ref["locator"]].compact_blank.join(" — ").presence || ref.to_json
      else
        ref.to_s
      end
    end.compact_blank.join("; ").presence || "—"
  end

  def ros_agent_draft_date_mapping_label(date_mapping)
    source_days = Array(date_mapping.to_h["source_days"])
    return "—" if source_days.blank?

    source_days.map do |day|
      if day.is_a?(Hash)
        [day["source_label"], day["target_date"]].compact_blank.join(" → ").presence || day.to_json
      else
        day.to_s
      end
    end.compact_blank.join("; ")
  end

  def ros_agent_draft_item_value(entry, key)
    value = entry[key]
    return "—" if value.nil? || value == ""

    case value
    when Array
      value.to_json
    when Hash
      value.to_json
    else
      value.to_s
    end
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
    item.duration_minutes.present? ? "#{item.duration_minutes} min" : "—"
  end

  def calendar_item_status_label(item)
    status_key = item.status.to_s
    return "Planned" if status_key.blank?

    status_key.humanize.titleize
  end

  def calendar_item_team_values(item)
    linked_names = Array(item.team_members)
                     .map { |member| member.name.to_s.strip }
                     .reject(&:blank?)
                     .sort_by(&:downcase)
    extra_names = item.additional_team_members.to_s
                      .split(/[,\n;]+/)
                      .map(&:strip)
                      .reject(&:blank?)

    (linked_names + extra_names).uniq
  end

  def calendar_item_team_label(item)
    linked_names = Array(item.team_members)
                     .map { |member| member.name.to_s.strip }
                     .reject(&:blank?)
                     .sort_by(&:downcase)
    extras = item.additional_team_members.to_s.strip

    [linked_names.join(", "), extras].reject(&:blank?).join("; ").presence || "—"
  end

  def calendar_item_search_text(item)
    [
      item.title,
      item.vendor_name,
      item.location_name,
      item.notes,
      calendar_item_team_label(item)
    ]
      .map { |value| normalize_calendar_filter_value(value) }
      .reject(&:blank?)
      .join(" ")
  end

  def calendar_item_filter_values(item, facet)
    values = case facet.to_sym
             when :vendor
               value = item.vendor_name.to_s.strip
               value.present? ? [ value ] : []
             when :location
               value = item.location_name.to_s.strip
               value.present? ? [ value ] : []
             when :team
               calendar_item_team_values(item)
             when :tag
               Array(item.event_calendar_tags)
                 .map { |tag| tag.name.to_s.strip }
                 .reject(&:blank?)
             else
               []
             end

    normalized_values = values
                          .map { |value| value.to_s.strip }
                          .reject(&:blank?)
                          .uniq

    normalized_values.presence || [ CALENDAR_FILTER_NONE_VALUE ]
  end

  def calendar_filter_options(items, facet)
    labels_by_token = {}

    Array(items).each do |item|
      calendar_item_filter_values(item, facet).each do |value|
        next if value == CALENDAR_FILTER_NONE_VALUE

        token = calendar_filter_token(value)
        next if token.blank?

        labels_by_token[token] ||= value
      end
    end

    [
      { label: "None", value: CALENDAR_FILTER_NONE_VALUE },
      *labels_by_token.values
                      .sort_by { |label| normalize_calendar_filter_value(label) }
                      .map do |label|
                        {
                          label: label,
                          value: calendar_filter_token(label)
                        }
                      end
    ]
  end

  def calendar_tag_filter_options(calendar)
    return [{ label: "None", value: CALENDAR_FILTER_NONE_VALUE }] unless calendar

    [
      { label: "None", value: CALENDAR_FILTER_NONE_VALUE },
      *calendar.event_calendar_tags
               .order(:position, :name)
               .map do |tag|
                 {
                   label: tag.name,
                   value: calendar_filter_token(tag.name)
                 }
               end
    ]
  end

  def calendar_filter_none_value
    CALENDAR_FILTER_NONE_VALUE
  end

  def calendar_item_filter_values_json(item, facet)
    calendar_item_filter_values(item, facet)
      .map { |value| value == CALENDAR_FILTER_NONE_VALUE ? value : calendar_filter_token(value) }
      .uniq
      .to_json
  end

  def calendar_item_tags_label(item)
    names = item.event_calendar_tags.map(&:name).reject(&:blank?)
    names.any? ? names.join(', ') : "—"
  end

  def calendar_item_date_bucket(item, timezone)
    start_time = item.effective_starts_at&.in_time_zone(timezone)
    return "Date TBD" unless start_time

    start_time.strftime("%A, %B %-d")
  end

  def calendar_item_segment_key(item, timezone, segment_granularity = EventCalendarView::SEGMENT_GRANULARITIES[:day])
    start_time = item.effective_starts_at&.in_time_zone(timezone)
    return "Date TBD" unless start_time

    if segment_granularity.to_s == EventCalendarView::SEGMENT_GRANULARITIES[:month]
      start_time.strftime("%Y-%m")
    else
      calendar_item_date_bucket(item, timezone)
    end
  end

  def calendar_item_segment_label(item, timezone, segment_granularity = EventCalendarView::SEGMENT_GRANULARITIES[:day])
    if segment_granularity.to_s == EventCalendarView::SEGMENT_GRANULARITIES[:month]
      calendar_item_month_year_label(item, timezone)
    else
      calendar_item_date_bucket(item, timezone)
    end
  end

  def calendar_item_month_year_label(item, timezone)
    start_time = item.effective_starts_at&.in_time_zone(timezone)
    return "Date TBD" unless start_time

    start_time.strftime("%B %Y")
  end

  def calendar_item_row_classes(item)
    classes = []
    classes << "calendar-row--to-be-confirmed" if item.to_be_confirmed?
    classes << "calendar-row--completed" if item.completed?
    classes << "calendar-row--critical" if item.critical?
    classes << "calendar-row--milestone" if item.milestone?
    classes.join(" ")
  end

  def calendar_item_relative_tooltip(item)
    return nil unless item.relative?
    anchor = item.relative_anchor
    return nil unless anchor

    offset_minutes = item.relative_offset_minutes.to_i
    direction = item.relative_before? ? "before" : "after"
    anchor_point = item.relative_to_anchor_end? ? "end" : "start"

    offset_label = if offset_minutes.zero?
                     "At the #{anchor_point} of #{anchor.title}"
                   else
                     minutes = offset_minutes.abs
                     parts = []
                     hours = minutes / 60
                     mins = minutes % 60
                     parts << "#{hours} #{'hour'.pluralize(hours)}" if hours.positive?
                     parts << "#{mins} #{'minute'.pluralize(mins)}" if mins.positive?
                     "#{parts.join(' ')} #{direction} #{anchor.title} #{anchor_point}s"
                   end

    offset_label
  end

  def calendar_tag_style(tag)
    color = tag.color_token.to_s.strip
    return nil if color.blank?

    styles = [
      "--tag-color: #{color}",
      "--tag-border-color: #{color}"
    ]

    rgb = css_color_to_rgb(color)
    styles << "--tag-text-color: #{contrasting_text_color_for_rgb(*rgb)}" if rgb

    styles.join('; ')
  end

  private

  def normalize_calendar_filter_value(value)
    value.to_s.downcase.squish
  end

  def calendar_filter_token(value)
    normalize_calendar_filter_value(value).parameterize
  end

  def css_color_to_rgb(value)
    token = value.to_s.strip
    return nil if token.blank?

    if hex_color?(token)
      return hex_components(token)
    end

    # Basic rgb()/rgba() parser (commas or spaces, optional alpha ignored).
    if (match = token.match(/\Argb(a)?\((.*)\)\z/i))
      raw = match[2].to_s.strip
      raw = raw.split('/').first.to_s
      parts = raw.include?(',') ? raw.split(',') : raw.split(/\s+/)
      parts = parts.map(&:strip).reject(&:blank?)
      return nil if parts.length < 3

      r = css_channel_to_255(parts[0])
      g = css_channel_to_255(parts[1])
      b = css_channel_to_255(parts[2])
      return nil unless r && g && b

      return [r, g, b]
    end

    hex = CSS_NAMED_COLORS[token.downcase]
    return nil unless hex

    hex_components(hex)
  end

  def css_channel_to_255(raw)
    token = raw.to_s.strip
    return nil if token.blank?

    if token.end_with?('%')
      percent = Float(token.delete_suffix('%'))
      percent = [[percent, 0.0].max, 100.0].min
      return (255 * (percent / 100.0)).round
    end

    number = Float(token)
    number = [[number, 0.0].max, 255.0].min
    number.round
  rescue ArgumentError, TypeError
    nil
  end

  def hex_color?(value)
    value.match?(/\A#(?:[0-9a-fA-F]{3}){1,2}\z/)
  end

  def hex_components(hex)
    rgb = hex.delete('#')
    rgb = rgb.chars.map { |c| c * 2 }.join if rgb.length == 3
    r = rgb[0..1].to_i(16)
    g = rgb[2..3].to_i(16)
    b = rgb[4..5].to_i(16)
    [r, g, b]
  end

  def contrasting_text_color_for_rgb(r, g, b)
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

  def format_clock_time(time)
    time.strftime("%l:%M %p").strip
  end

  def midnight?(time)
    time.strftime("%H:%M") == "00:00"
  end

  def effective_time_label(start_time, finish_time, timezone)
    start_time = start_time&.in_time_zone(timezone)
    finish_time = finish_time&.in_time_zone(timezone)
    return unless start_time

    if finish_time
      "#{format_time_or_date(start_time)} – #{format_time_only(finish_time)}"
    else
      format_time_or_date(start_time)
    end
  end

  def effective_time_only_label(start_time, finish_time, timezone)
    start_time = start_time&.in_time_zone(timezone)
    finish_time = finish_time&.in_time_zone(timezone)
    return unless start_time

    if finish_time
      "#{format_clock_time(start_time)} – #{format_clock_time(finish_time)}"
    else
      format_clock_time(start_time)
    end
  end

  def parse_ros_agent_draft_date(value)
    return if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def ros_agent_draft_entry_start_time(entry, timezone)
    return unless entry

    parse_ros_agent_draft_time(entry.dig("timing", "starts_at").presence || entry["starts_at"].presence, timezone)
  end

  def ros_agent_draft_entry_finish_time(entry, start_time, timezone)
    return unless entry

    explicit_finish = parse_ros_agent_draft_time(
      entry.dig("timing", "ends_at").presence || entry["ends_at"].presence,
      timezone
    )
    return explicit_finish if explicit_finish
    return unless start_time && entry["duration_minutes"].present?

    duration_minutes = Integer(entry["duration_minutes"], exception: false)
    return unless duration_minutes&.positive?

    start_time + duration_minutes.minutes
  end

  def parse_ros_agent_draft_time(value, timezone)
    return if value.blank?

    zone = Time.find_zone(timezone) || Time.zone
    zone.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def parseable_ros_agent_draft_datetime?(value)
    value.to_s.match?(/\A\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}/)
  end
end
