module GeneratedDocumentsHelper
  MARKDOWN_ALLOWED_TAGS = %w[
    p br ul ol li strong em a h2 h3 h4 h5 hr blockquote code pre
  ].freeze
  MARKDOWN_ALLOWED_ATTRIBUTES = %w[href title rel target].freeze
  MARKDOWN_ALLOWED_PROTOCOLS = %w[http https mailto].freeze
  WEDDING_PARTY_REFERENCE_CONTENT = {
    event_timelines: [
      {
        day: "Friday, August 29",
        entries: [
          {
            title: "Ceremony Rehearsal",
            venue: "Le Meridien",
            sublocation: "Pierce Arrow Board Room",
            time: "5:30 PM",
            note: "Please meet at 5:15 PM."
          },
          {
            title: "Rehearsal Dinner",
            venue: "Provisions",
            time: "7:00 PM to 10:00 PM"
          }
        ]
      },
      {
        day: "Saturday, August 30",
        entries: [
          {
            title: "Welcome Party",
            venue: "Salt & Olive",
            time: "6:00 PM to 9:00 PM"
          }
        ]
      },
      {
        day: "Sunday, August 31",
        entries: [
          {
            title: "Ceremony",
            venue: "La Caille",
            time: "4:30 PM to 5:00 PM"
          },
          {
            title: "Cocktails",
            venue: "La Caille",
            time: "5:00 PM to 6:00 PM"
          },
          {
            title: "Dinner & Dancing",
            venue: "La Caille",
            time: "6:00 PM to 10:00 PM"
          },
          {
            title: "After Party",
            venue: "Le Meridien",
            sublocation: "Van Ryder",
            time: "10:00 PM to 12:00 AM"
          }
        ]
      },
      {
        day: "Monday, September 1",
        entries: [
          {
            title: "Farewell Brunch",
            venue: "Le Meridien",
            sublocation: "Second Floor Pre-Function Space",
            time: "10:00 AM to 1:00 PM"
          }
        ]
      }
    ],
    transportation_details: [
      {
        day: "Friday, August 29",
        paragraphs: [
          "Guests attending the Rehearsal should meet in the Pierce Arrow Board Room at Le Meridien at 5:15 PM. Please arrive dressed for dinner.",
          "At the conclusion of the Rehearsal, transportation to the Rehearsal Dinner will depart from the hotel entrance at 6:30 PM. Return transportation will be available at the conclusion of the Rehearsal Dinner, around 10:00 PM."
        ]
      },
      {
        day: "Saturday, August 30",
        paragraphs: [
          "Guests attending Oktoberfest at Snowbird should meet at the hotel entrance to depart at 11:30 AM. Return shuttle departure at 2:30 PM.",
          "Wedding Party & all guests attending the Welcome Party should meet at the hotel entrance to depart at 5:45 PM. Return shuttles available at 8:00 PM and 9:00 PM."
        ]
      },
      {
        day: "Sunday, August 31",
        paragraphs: [
          "Groom's family and attendants depart Le Meridien at 1:10 PM from hotel entrance.",
          "Bride's attendants meet in the Le Meridien lobby at 1:15 PM for 1:30 PM departure with Hannah and immediate family.",
          "Wedding guests depart from Le Meridien entrance at 3:30 PM.",
          "Return shuttles to Le Meridien available at 9:30 PM and 10:30 PM."
        ]
      }
    ],
    excursion: {
      title: "Oktoberfest Excursions",
      date: "Saturday, August 30",
      transportation: "Guests attending Oktoberfest at Snowbird should meet at the hotel entrance to depart at 11:30 AM. Return shuttle departure at 2:30 PM.",
      details_text: "For more details, please visit the Oktoberfest link.",
      link_label: "Oktoberfest",
      link_url: "https://example.com/oktoberfest"
    },
    getting_ready: [
      {
        title: "Hannah's Attendants",
        location: "Pierce Arrow Board Room",
        paragraphs: [
          "Please steam your dress in advance and bring it to the Pierce Arrow Board Room. Arrive with clean and moisturized skin and clean, dry hair that has been blow-dried with a paddle brush or round brush the night before.",
          "Please bring a bag (easily identified with your name) for your extra clothes and belongings. We'll ensure your items are brought to La Caille or returned to your hotel rooms."
        ]
      },
      {
        title: "Dan's Attendants",
        location: "Dan's Hotel Suite",
        paragraphs: [
          "On the wedding day, Dan & the Groom's Party will be having lunch at Adelaide's, the restaurant on the lobby level of Le Meridien. Please meet at Adelaide's at 11:00 AM.",
          "Before lunch, please bring your pressed suits, shined shoes, and accessories to Dan's hotel suite. You'll dress there and then gather in the hotel lobby at 1:00 PM.",
          "Please bring a bag (easily identified with your name) for your extra clothes and belongings. We'll ensure that your items are brought to La Caille or returned to your hotel rooms."
        ]
      }
    ],
    wedding_party: [
      {
        title: "Bride's Side",
        members: [
          { name: "Hannah Isakowitz", role: "Bride" },
          { name: "Missy Isakowitz", role: "Mother of the Bride" },
          { name: "Mark Isakowitz", role: "Father of the Bride" },
          { name: "Sharon Newman", role: "Grandmother of the Bride" },
          { name: "Carly Graham", role: "Matron of Honor and Sister of the Bride" },
          { name: "Allie Isakowitz", role: "Bridesmaid and Sister-in-Law of the Bride" },
          { name: "Julia Barone", role: "Bridesmaid" },
          { name: "Danielle Bruns", role: "Bridesmaid" },
          { name: "Lindsay Stassinos", role: "Bridesmaid" },
          { name: "Sarah Iacomelli", role: "Bridesmaid" },
          { name: "Erin Hess", role: "Bridesmaid" },
          { name: "Michael Denzel", role: "Bride's Attendant" },
          { name: "Emmy Graham", role: "Bride's Niece & Flower Kid" },
          { name: "Ava Graham", role: "Bride's Niece & Flower Kid" },
          { name: "Luca Isakowitz", role: "Nephew of the Bride & Flower Kid" }
        ]
      },
      {
        title: "Groom's Side",
        members: [
          { name: "Dan Greener", role: "Groom" },
          { name: "Ruth Greener", role: "Mother of the Groom" },
          { name: "Jeff Greener", role: "Father of the Groom" },
          { name: "Marilyn Greener", role: "Grandmother of the Groom" },
          { name: "Samuel Bonolio", role: "Grandfather of the Groom" },
          { name: "Andrew Greener", role: "Best Man and Brother of the Groom" },
          { name: "Michael Greener", role: "Best Man and Brother of the Groom" },
          { name: "Zach Isakowitz", role: "Groomsman and Brother of the Bride" },
          { name: "Eric Graham", role: "Groomsman and Brother-in-Law of the Bride" },
          { name: "Christian Maine De Biran", role: "Groomsman" },
          { name: "Daniel Marcus", role: "Groomsman" },
          { name: "Harlan Pittell", role: "Groomsman" },
          { name: "Dylan Magalit", role: "Groomsman" },
          { name: "Jon Schneidman", role: "Groomsman" },
          { name: "Max Levitin", role: "Groomsman" },
          { name: "Clark Chamerlin", role: "Groomsman" }
        ]
      }
    ]
  }.freeze

  def generated_segment_body_markdown(segment)
    options = if segment.respond_to?(:html_options)
                segment.html_options
              elsif segment.respond_to?(:source_ref) && segment.source_ref.is_a?(Hash)
                source_options = segment.source_ref["options"]
                source_options.is_a?(Hash) ? source_options : {}
              else
                {}
              end

    body_markdown = options.is_a?(Hash) ? options["body_markdown"].to_s : ""
    return body_markdown if body_markdown.present?

    view_key = if segment.respond_to?(:html_view_key)
                 segment.html_view_key
               elsif segment.respond_to?(:source_ref) && segment.source_ref.is_a?(Hash)
                 segment.source_ref["view_key"]
               end

    DocumentSegment.default_body_markdown_for(view_key)
  end

  def render_generated_markdown(markdown_text)
    html = render_generated_markdown_segments(markdown_text.to_s)

    fragment = Nokogiri::HTML::DocumentFragment.parse(html.to_s)
    fragment.css("a").each do |link|
      normalize_generated_link!(link)
    end

    fragment.to_html.html_safe
  end

  def generated_event_overview_date_range(event)
    return "Date TBD" unless event.starts_on.present? || event.ends_on.present?

    if event.starts_on.present? && event.ends_on.present? && event.ends_on != event.starts_on
      "#{event.starts_on.to_fs(:long)} - #{event.ends_on.to_fs(:long)}"
    else
      event.starts_on.presence&.to_fs(:long) || event.ends_on.to_fs(:long)
    end
  end

  def generated_event_overview_planners(event)
    event.planner_team_members.includes(:user).ordered_for_display.filter_map do |member|
      user = member.user
      next unless user

      {
        lead: member.lead_planner?,
        name: user.name.to_s.strip,
        title: user.title.to_s.strip.presence,
        email: user.display_email.to_s.strip.presence,
        phone: user.phone_number.to_s.strip.presence
      }
    end
  end

  def generated_event_overview_timeline(event)
    generated_wedding_party_reference_milestones(event)
  end

  def generated_event_overview_timeline_time(item, timezone)
    start_time = item.effective_starts_at&.in_time_zone(timezone)
    end_time = item.effective_ends_at&.in_time_zone(timezone)
    return "Date TBD" unless start_time

    start_label = start_time.strftime("%l:%M %p").strip
    return start_label unless end_time

    "#{start_label} to #{end_time.strftime("%l:%M %p").strip}"
  end

  def generated_event_overview_vendors(event)
    event.event_vendors.includes(:global_vendor).ordered.filter_map do |vendor|
      contacts = Array(vendor.contacts).filter_map do |contact|
        contact_hash = contact.to_h.stringify_keys

        normalized_contact = {
          name: contact_hash["name"].to_s.strip.presence,
          title: contact_hash["title"].to_s.strip.presence,
          email: contact_hash["email"].to_s.strip.presence,
          phone: contact_hash["phone"].to_s.strip.presence
        }

        next if normalized_contact.values.all?(&:blank?)

        normalized_contact
      end

      next if contacts.empty?

      {
        name: generated_event_overview_vendor_name(vendor),
        vendor_type: generated_event_overview_vendor_type(vendor),
        social_handle: generated_event_overview_social_handle(generated_event_overview_vendor_social_handle(vendor)),
        contacts: contacts
      }
    end
  end

  def generated_wedding_party_reference_content
    WEDDING_PARTY_REFERENCE_CONTENT.deep_dup
  end

  def generated_wedding_party_reference_milestones(event)
    calendar = event.run_of_show_calendar
    timezone = calendar&.timezone.presence || Time.zone.name
    return { timezone:, groups: [] } unless calendar

    milestone_items = calendar.calendar_items
                             .includes(:event_calendar_tags, :relative_anchor)
                             .to_a
                             .select(&:milestone?)
                             .sort_by do |item|
      start_time = item.effective_starts_at&.in_time_zone(timezone)
      [start_time&.to_f || Float::INFINITY, item.title.to_s.downcase]
    end

    groups = milestone_items
               .group_by do |item|
      start_time = item.effective_starts_at&.in_time_zone(timezone)
      start_time ? start_time.strftime("%A, %B %-d") : "Date TBD"
    end
               .map do |date_label, items|
      {
        date_label:,
        items:
      }
    end

    { timezone:, groups: groups }
  end

  private

  def generated_event_overview_vendor_name(vendor)
    vendor.global_vendor&.name.to_s.strip.presence || vendor.name.to_s.strip
  end

  def generated_event_overview_vendor_type(vendor)
    vendor.vendor_type.to_s.strip.presence || vendor.global_vendor&.default_vendor_type.to_s.strip.presence
  end

  def generated_event_overview_vendor_social_handle(vendor)
    vendor.social_handle.to_s.strip.presence || vendor.global_vendor&.default_social_handle.to_s.strip.presence
  end

  def generated_event_overview_social_handle(value)
    handle = value.to_s.strip
    return if handle.blank?

    handle.start_with?("@") ? handle : "@#{handle}"
  end

  def render_generated_markdown_segments(markdown_text)
    split_generated_markdown_segments(markdown_text).map do |segment|
      if segment[:type] == :columns
        render_generated_markdown_columns(segment[:columns])
      else
        render_generated_markdown_fragment(segment[:content])
      end
    end.join
  end

  def split_generated_markdown_segments(markdown_text)
    lines = markdown_text.to_s.lines
    segments = []
    markdown_buffer = +""
    index = 0

    while index < lines.length
      if lines[index].strip == ":::columns"
        parsed_block = parse_generated_columns_block(lines, index)
        if parsed_block[:valid]
          segments << { type: :markdown, content: markdown_buffer } if markdown_buffer.present?
          markdown_buffer = +""
          segments << { type: :columns, columns: parsed_block[:columns] }
        else
          markdown_buffer << parsed_block[:raw]
        end

        index = parsed_block[:next_index]
        next
      end

      markdown_buffer << lines[index]
      index += 1
    end

    segments << { type: :markdown, content: markdown_buffer } if markdown_buffer.present?
    segments
  end

  def parse_generated_columns_block(lines, start_index)
    raw = +""
    raw << lines[start_index]
    index = start_index + 1
    columns = []

    while index < lines.length
      line = lines[index]
      raw << line
      stripped = line.strip

      if stripped == ":::column"
        column_parse = parse_generated_column(lines, index + 1)
        raw << column_parse[:raw]
        return invalid_generated_columns_parse(raw, column_parse[:next_index]) unless column_parse[:valid]

        columns << column_parse[:content]
        index = column_parse[:next_index]
        next
      end

      if stripped == ":::"
        return invalid_generated_columns_parse(raw, index + 1) if columns.empty?

        combined_second_column = columns.drop(1).join("\n")
        return {
          valid: true,
          next_index: index + 1,
          columns: [ columns.first.to_s, combined_second_column.to_s ]
        }
      end

      return invalid_generated_columns_parse(raw, index + 1)
    end

    invalid_generated_columns_parse(raw, index)
  end

  def parse_generated_column(lines, start_index)
    content = +""
    raw = +""
    index = start_index

    while index < lines.length
      line = lines[index]
      stripped = line.strip

      if stripped == ":::"
        raw << line
        return { valid: true, next_index: index + 1, content: content, raw: raw }
      end

      raw << line
      content << line
      index += 1
    end

    { valid: false, next_index: index, raw: raw }
  end

  def invalid_generated_columns_parse(raw, next_index)
    { valid: false, next_index: next_index, raw: raw }
  end

  def render_generated_markdown_columns(columns)
    first_column_html = render_generated_markdown_fragment(columns.first.to_s)
    second_column_html = render_generated_markdown_fragment(columns.second.to_s)

    <<~HTML
      <div class="generated-text-columns">
        <div class="generated-text-column">#{first_column_html}</div>
        <div class="generated-text-column">#{second_column_html}</div>
      </div>
    HTML
  end

  def render_generated_markdown_fragment(markdown_text)
    normalized_markdown = markdown_text.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    html = Commonmarker.to_html(normalized_markdown)
    sanitize(
      html,
      tags: MARKDOWN_ALLOWED_TAGS,
      attributes: MARKDOWN_ALLOWED_ATTRIBUTES
    ).to_s
  end

  def normalize_generated_link!(link)
    href = link["href"].to_s.strip
    return link.remove_attribute("href") if href.blank?

    uri = URI.parse(href)
    scheme = uri.scheme&.downcase

    if scheme.present? && !MARKDOWN_ALLOWED_PROTOCOLS.include?(scheme)
      link.remove_attribute("href")
      link.remove_attribute("target")
      link.remove_attribute("rel")
      return
    end

    if %w[http https].include?(scheme)
      link["target"] = "_blank"
      link["rel"] = "noopener noreferrer"
    else
      link.remove_attribute("target")
      link.remove_attribute("rel")
    end
  rescue URI::InvalidURIError
    link.remove_attribute("href")
    link.remove_attribute("target")
    link.remove_attribute("rel")
  end
end
