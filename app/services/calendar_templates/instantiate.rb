module CalendarTemplates
  class Instantiate
    Result = Struct.new(:calendar, :item_map, :tag_map, :views, keyword_init: true)

    def initialize(template:, event:, calendar_name: nil, client_visible: false)
      @template = template
      @event = event
      @calendar_name = calendar_name.presence || template.name
      @client_visible = client_visible
    end

    def call
      ActiveRecord::Base.transaction do
        calendar = build_calendar!
        tag_map = copy_tags!(calendar)
        item_map = copy_items!(calendar, tag_map)
        assign_relative_anchors!(item_map, template.calendar_template_items)
        views = copy_views!(calendar, tag_map)

        Calendars::CascadeScheduler.new(calendar).call

        Result.new(
          calendar: calendar,
          item_map: item_map,
          tag_map: tag_map,
          views: views
        )
      end
    end

    private

    attr_reader :template, :event, :calendar_name, :client_visible

    def build_calendar!
      event.event_calendars.create!(
        name: calendar_name,
        slug: calendar_name.parameterize,
        description: template.description,
        timezone: template.default_timezone,
        kind: EventCalendar::KINDS[:master],
        client_visible: client_visible,
        template_source: template,
        template_version: template.version
      )
    end

    def copy_tags!(calendar)
      template.calendar_template_tags.order(:position).each_with_object({}) do |template_tag, mapping|
        mapping[template_tag.id] = calendar.event_calendar_tags.create!(
          name: template_tag.name,
          color_token: template_tag.color_token,
          position: template_tag.position
        )
      end
    end

    def copy_items!(calendar, tag_map)
      template.calendar_template_items.ordered.each_with_object({}) do |template_item, mapping|
        item = calendar.calendar_items.create!(
          title: template_item.title,
          notes: template_item.notes,
          duration_minutes: template_item.duration_minutes,
          relative_offset_minutes: template_item.default_offset_minutes,
          relative_before: template_item.default_before,
          locked: template_item.locked_by_default,
          position: template_item.position
        )

        template_item.calendar_template_tags.each do |template_tag|
          next unless tag_map[template_tag.id]

          CalendarItemTag.create!(
            calendar_item: item,
            event_calendar_tag: tag_map[template_tag.id]
          )
        end

        mapping[template_item.id] = item
      end
    end

    def assign_relative_anchors!(item_map, template_items)
      template_items.each do |template_item|
        next if template_item.relative_anchor_template_item_id.blank?

        new_item = item_map.fetch(template_item.id)
        anchor_item = item_map[template_item.relative_anchor_template_item_id]
        next unless anchor_item

        new_item.update!(relative_anchor: anchor_item)
      end
    end

    def copy_views!(calendar, tag_map)
      template.calendar_template_views.order(:position).map do |template_view|
        mapped_tag_ids = template_view.tag_filter.map { |tag_id| tag_map[tag_id]&.id }.compact

        calendar.event_calendar_views.create!(
          name: template_view.name,
          slug: template_view.name.parameterize,
          description: template_view.description,
          tag_filter: mapped_tag_ids,
          hide_locked: template_view.hide_locked,
          client_visible: template_view.client_visible_by_default,
          position: template_view.position
        )
      end
    end
  end
end
