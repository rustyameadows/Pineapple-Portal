module GeneratedDocumentsHelper
  require "uri"

  MARKDOWN_ALLOWED_TAGS = %w[
    p br ul ol li strong em a h2 h3 h4 h5 hr blockquote code pre
  ].freeze
  MARKDOWN_ALLOWED_ATTRIBUTES = %w[href title rel target].freeze
  MARKDOWN_ALLOWED_PROTOCOLS = %w[http https mailto].freeze
  PACKET_RICH_TEXT_ALLOWED_TAGS = %w[
    p br strong em a h1 h2 h3 h4 h5 h6
  ].freeze
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
    ]
  }.freeze

  def generated_uploaded_pdf_status(segment)
    return unless segment.pdf_asset?

    source = segment.respond_to?(:source) ? segment.source : segment
    uploaded_document = Documents::Generated::UploadedDocumentResolver.new(source).call
    return { state: :missing } unless uploaded_document

    current_hash = Documents::Generated::SegmentHasher.call(source)
    state = if segment.last_render_error.present?
              :failed
    elsif !segment.cached?
              :preparing
    elsif source.cache_stale?(current_hash)
              :new_version
    else
              :ready
    end

    { state: state, document: uploaded_document }
  end

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

  def generated_event_overview_venue_addresses(event)
    event.event_venues.ordered.filter_map do |venue|
      address = venue.address.to_s.strip.presence
      next unless address

      {
        name: venue.name.to_s.strip.presence || "Venue",
        address: address
      }
    end
  end

  def generated_event_overview_vendors(event)
    Vendors::PlanningCompany.excluding(event.event_vendors).includes(:global_vendor).ordered.map do |vendor|
      {
        name: generated_event_overview_vendor_name(vendor),
        vendor_type: generated_event_overview_vendor_type(vendor),
        social_handle: generated_event_overview_social_handle(generated_event_overview_vendor_social_handle(vendor))
      }
    end
  end

  def generated_event_overview_social_media_rows(event)
    rows = []
    lead_planner = generated_event_overview_planners(event).find { |planner| planner[:lead] }
    planning_company = Vendors::PlanningCompany.global_vendor_for(event)

    if lead_planner
      rows << {
        label: "Planning, Design & Coordination",
        company_name: planning_company.name.to_s.strip,
        social_handle: generated_event_overview_social_handle(
          planning_company.default_social_handle
        )
      }
    end

    rows + generated_event_overview_vendors(event).map do |vendor|
      {
        label: vendor[:vendor_type].presence,
        company_name: vendor[:name],
        social_handle: vendor[:social_handle]
      }
    end
  end

  def generated_builder_return_to(path, open_group_source_id: nil)
    return path if path.blank? || open_group_source_id.blank?

    uri = URI.parse(path)
    params = Rack::Utils.parse_nested_query(uri.query)
    params["open_group_source_id"] = open_group_source_id.to_s
    uri.query = params.to_query.presence
    uri.to_s
  rescue URI::InvalidURIError
    path
  end

  def generated_event_overview_primary_rows(event)
    rows = [
      [ "Date", generated_event_overview_date_range(event) ],
      [ "Location", event.location.presence || "Location TBD" ]
    ]

    guest_count = event.guest_count.to_s.strip.presence
    rows << [ "Guest Count", guest_count ] if guest_count
    rows
  end

  def generated_event_overview_style_rows(event)
    [
      [ "Attire", event.attire.to_s.strip.presence ],
      [ "Color Palette", event.color_palette.to_s.strip.presence ],
      [ "Style", event.style.to_s.strip.presence ]
    ].select { |_label, value| value.present? }
  end

  def generated_event_overview_vip_rows(event)
    event.event_guests.key_people.ordered.filter_map do |guest|
      next unless guest.vip?

      label = guest.relationship.to_s.strip.presence
      value = guest.full_name.to_s.strip.presence
      next if label.blank? || value.blank?

      [ label, value ]
    end
  end

  def generated_vendor_contacts_groups(event)
    planning_company = Vendors::PlanningCompany.global_vendor_for(event)

    [
      {
        category: "Planning",
        vendor_name: planning_company.name.to_s.strip,
        team_meals: event.pineapple_team_meals.to_s.strip.presence,
        rows: generated_vendor_contacts_planner_rows(event)
      }
    ] + Vendors::PlanningCompany
         .excluding(event.event_vendors)
         .includes(:global_vendor, event_vendor_contacts: :global_vendor_contact)
         .ordered
         .map do |vendor|
      {
        category: generated_vendor_contacts_visible_value(generated_event_overview_vendor_type(vendor).presence),
        vendor_name: generated_vendor_contacts_visible_value(generated_event_overview_vendor_name(vendor).presence),
        team_meals: vendor.team_meals.to_s.strip.presence,
        rows: generated_vendor_contacts_vendor_rows(vendor)
      }
    end
  end

  def generated_packet_rich_text_present?(text)
    text.to_s.strip.present?
  end

  def render_generated_packet_rich_text(markdown_text)
    fragment = generated_packet_rich_text_fragment(markdown_text)
    safe_join(
      generated_packet_rich_text_sections(fragment).map do |section|
        generated_packet_rich_text_section_html(section)
      end
    )
  end

  def render_generated_packet_rich_text_content(markdown_text)
    fragment = generated_packet_rich_text_fragment(markdown_text)
    safe_join(fragment.children.map { |node| node.to_html.html_safe })
  end

  def generated_packet_text_paragraphs(text)
    text.to_s.split(/\r?\n+/).filter_map do |paragraph|
      paragraph.to_s.strip.presence
    end
  end

  def generated_wedding_party_reference_content
    WEDDING_PARTY_REFERENCE_CONTENT.deep_dup
  end

  def generated_wedding_party_reference_key_people(event)
    event.event_key_person_groups.includes(:event_guests).ordered.filter_map do |group|
      guests = group.event_guests.select(&:key_person?).sort_by { |guest| [ guest.position, guest.id ] }
      next if guests.empty?

      {
        title: group.name,
        members: guests.map do |guest|
          {
            name: guest.full_name,
            role: guest.relationship.to_s.strip
          }
        end
      }
    end
  end

  def generated_wedding_party_reference_timeline(event, segment)
    Documents::Generated::WeddingPartyReferenceTimeline.new(
      event: event,
      options: generated_document_segment_options(segment)
    ).call
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
      [ start_time&.to_f || Float::INFINITY, item.title.to_s.downcase ]
    end

    groups = milestone_items
               .group_by do |item|
      start_time = item.effective_starts_at&.in_time_zone(timezone)
      start_time ? start_time.strftime("%A, %B %-d") : "Date TBD"
    end
               .map do |date_label, items|
      {
        date_label:,
        items:,
        transportation_notes: items.filter_map { |item| item.transportation_note.to_s.strip.presence }
      }
    end

    { timezone:, groups: groups }
  end

  private

  def generated_packet_rich_text_fragment(markdown_text)
    normalized_markdown = markdown_text.to_s.encode(Encoding::UTF_8, invalid: :replace, undef: :replace)
    html = Commonmarker.to_html(normalized_markdown)
    sanitized_html = sanitize(
      html,
      tags: PACKET_RICH_TEXT_ALLOWED_TAGS,
      attributes: MARKDOWN_ALLOWED_ATTRIBUTES
    ).to_s

    fragment = Nokogiri::HTML::DocumentFragment.parse(sanitized_html)
    fragment.css("a").each do |link|
      normalize_generated_link!(link)
    end
    fragment
  end

  def generated_event_overview_vendor_name(vendor)
    vendor.global_vendor.name.to_s.strip
  end

  def generated_event_overview_vendor_type(vendor)
    vendor.vendor_type.to_s.strip.presence || vendor.global_vendor&.default_vendor_type.to_s.strip.presence
  end

  def generated_event_overview_vendor_social_handle(vendor)
    vendor.global_vendor.default_social_handle.to_s.strip.presence
  end

  def generated_event_overview_social_handle(value)
    handle = value.to_s.strip
    return if handle.blank?

    handle.start_with?("@") ? handle : "@#{handle}"
  end

  def generated_vendor_contacts_planner_rows(event)
    rows = event.planner_team_members.includes(:user).ordered_for_display.filter_map do |member|
      user = member.user
      next unless user
      contact_name = user.name.to_s.strip

      {
        contact: contact_name,
        phone: generated_vendor_contacts_phone_value(contact_name, user.phone_number)
      }
    end

    rows.presence || [ generated_vendor_contacts_blank_row ]
  end

  def generated_vendor_contacts_vendor_rows(vendor)
    rows = vendor.selected_contacts.map do |contact|
      contact_name = contact.name.to_s.strip.presence || contact.title.to_s.strip.presence

      {
        contact: contact_name.to_s,
        phone: generated_vendor_contacts_phone_value(contact_name, contact.phone)
      }
    end

    rows.presence || [ generated_vendor_contacts_blank_row ]
  end

  def generated_vendor_contacts_blank_row
    {
      contact: "",
      phone: ""
    }
  end

  def generated_vendor_contacts_phone_value(contact_name, phone)
    phone_value = phone.to_s.strip
    return phone_value if phone_value.present?

    contact_name.to_s.strip.present? ? "—" : ""
  end

  def generated_vendor_contacts_visible_value(value)
    value.presence || "—"
  end

  def generated_document_segment_options(segment)
    if segment.respond_to?(:html_options)
      segment.html_options
    elsif segment.respond_to?(:source_ref) && segment.source_ref.is_a?(Hash)
      source_options = segment.source_ref["options"]
      source_options.is_a?(Hash) ? source_options : {}
    else
      {}
    end
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

  def generated_packet_rich_text_sections(fragment)
    sections = []
    current_section = { heading_html: nil, body_nodes: [] }

    fragment.children.each do |node|
      next if node.text? && node.text.strip.blank?

      if packet_heading_node?(node)
        sections << current_section if current_section[:heading_html].present? || current_section[:body_nodes].any?
        current_section = {
          heading_html: node.inner_html.to_s.strip.presence,
          body_nodes: []
        }
      else
        current_section[:body_nodes] << node.dup
      end
    end

    sections << current_section if current_section[:heading_html].present? || current_section[:body_nodes].any?
    sections
  end

  def generated_packet_rich_text_section_html(section)
    body_html = section[:body_nodes].map(&:to_html).join.html_safe

    if section[:heading_html].present?
      content_tag(:section, class: "generated-template--packet-sheet__subsection") do
        safe_join([
          content_tag(:h3, section[:heading_html].html_safe, class: "generated-template--packet-sheet__subsection-title"),
          content_tag(:div, body_html, class: "generated-template--packet-sheet__body")
        ])
      end
    else
      content_tag(:div, body_html, class: "generated-template--packet-sheet__body")
    end
  end

  def packet_heading_node?(node)
    node.element? && node.name.match?(/\Ah[1-6]\z/)
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
