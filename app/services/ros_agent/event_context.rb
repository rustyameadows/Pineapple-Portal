module RosAgent
  class EventContext
    def initialize(event)
      @event = event
      @calendar = event.run_of_show_calendar
    end

    def as_json(*)
      {
        event: event_payload,
        run_of_show_calendar: calendar_payload,
        current_calendar_items: current_calendar_items,
        vendors: vendors_payload,
        tags: tags_payload,
        views: views_payload,
        team: team_payload,
        defaults: defaults_payload
      }
    end

    private

    attr_reader :event, :calendar

    def event_payload
      {
        id: event.id,
        name: event.name,
        starts_on: event.starts_on&.iso8601,
        ends_on: event.ends_on&.iso8601,
        location: event.location,
        guest_count: event.guest_count,
        attire: event.attire,
        style: event.style,
        color_palette: event.color_palette,
        key_people_label: event.key_people_label,
        social_media_policy: event.social_media_policy,
        parking_details: event.parking_details,
        getting_ready_details: event.getting_ready_details
      }
    end

    def calendar_payload
      return {} unless calendar

      {
        id: calendar.id,
        name: calendar.name,
        timezone: calendar.timezone,
        client_visible: calendar.client_visible?
      }
    end

    def current_calendar_items
      return [] unless calendar

      calendar.calendar_items
              .includes(:relative_anchor, :event_calendar_tags, :team_members)
              .ordered
              .map { |item| item_payload(item) }
    end

    def item_payload(item)
      {
        id: item.id,
        title: item.title,
        notes: item.notes,
        starts_at: item.starts_at&.iso8601,
        effective_starts_at: item.effective_starts_at&.iso8601,
        effective_ends_at: item.effective_ends_at&.iso8601,
        duration_minutes: item.duration_minutes,
        status: item.status,
        locked: item.locked?,
        vendor_name: item.vendor_name,
        location_name: item.location_name,
        additional_team_members: item.additional_team_members,
        time_caption: item.time_caption,
        transportation_note: item.transportation_note,
        guest_count: item.guest_count,
        position: item.position,
        tags: item.event_calendar_tags.map(&:name),
        team_members: item.team_members.map { |member| { id: member.id, name: member.name } },
        relative_timing: relative_payload(item)
      }
    end

    def relative_payload(item)
      return nil if item.absolute?

      {
        anchor_id: item.relative_anchor_id,
        anchor_title: item.relative_anchor&.title,
        offset_minutes: item.relative_offset_minutes,
        before: item.relative_before?,
        to_anchor_end: item.relative_to_anchor_end?
      }
    end

    def tags_payload
      return [] unless calendar

      calendar.event_calendar_tags.order(:position, :name).map do |tag|
        { id: tag.id, name: tag.name, color_token: tag.color_token, position: tag.position }
      end
    end

    def vendors_payload
      event.event_vendors.includes(:global_vendor).ordered.map do |vendor|
        {
          id: vendor.id,
          global_vendor_id: vendor.global_vendor_id,
          name: vendor.name,
          vendor_type: vendor.vendor_type.presence || vendor.global_vendor&.default_vendor_type
        }
      end
    end

    def views_payload
      return [] unless calendar

      calendar.event_calendar_views.order(:position, :name).map do |view|
        {
          id: view.id,
          name: view.name,
          description: view.description,
          tag_filter: view.tag_filter,
          segment_granularity: view.segment_granularity,
          client_visible: view.client_visible?
        }
      end
    end

    def team_payload
      {
        planners: event.planner_team_members.includes(:user).order(:position).map do |member|
          { id: member.user_id, name: member.user&.name, lead: member.lead_planner? }
        end
      }
    end

    def defaults_payload
      {
        tags: RunOfShowDefaults::TAGS,
        views: RunOfShowDefaultViews::VIEWS
      }
    end
  end
end
