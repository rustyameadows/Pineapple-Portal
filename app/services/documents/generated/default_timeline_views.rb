module Documents
  module Generated
    class DefaultTimelineViews
      class << self
        def ensure_view!(event, view_name)
          new(event).ensure_view!(view_name)
        end
      end

      def initialize(event)
        @event = event
      end

      def ensure_view!(view_name)
        config = RunOfShowDefaultViews::VIEWS.find { |entry| entry[:name].to_s.casecmp?(view_name.to_s) }
        raise ArgumentError, "Unknown default timeline view: #{view_name}" unless config

        ensure_tags!(Array(config[:tag_names]))

        calendar.event_calendar_views.find_or_initialize_by(name: config[:name]).tap do |view|
          next if view.persisted?

          view.slug = generate_unique_slug(config[:name])
          view.description = config[:description]
          view.hide_locked = config.fetch(:hide_locked, false)
          view.client_visible = config.fetch(:client_visible, false)
          view.tag_filter = tag_ids_for(config[:tag_names])
          view.save!
        end
      end

      private

      attr_reader :event

      def calendar
        @calendar ||= event.run_of_show_calendar || event.event_calendars.create!(
          name: "Run of Show",
          timezone: EventCalendar::DEFAULT_TIMEZONE
        )
      end

      def ensure_tags!(tag_names)
        defaults = RunOfShowDefaults::TAGS.index_by { |tag| tag[:name].to_s.strip.downcase }

        Array(tag_names).each do |name|
          normalized_name = name.to_s.strip
          next if normalized_name.blank?
          next if calendar.event_calendar_tags.exists?(name: normalized_name)

          default = defaults[normalized_name.downcase]
          calendar.event_calendar_tags.create!(
            name: normalized_name,
            color_token: default&.fetch(:color_token, nil)
          )
        end
      end

      def tag_ids_for(tag_names)
        lookup = calendar.event_calendar_tags.index_by { |tag| tag.name.to_s.strip.downcase }
        Array(tag_names).filter_map { |name| lookup[name.to_s.strip.downcase]&.id }
      end

      def generate_unique_slug(name)
        base = name.to_s.parameterize
        candidate = base
        suffix = 2

        while calendar.event_calendar_views.exists?(slug: candidate)
          candidate = "#{base}-#{suffix}"
          suffix += 1
        end

        candidate
      end
    end
  end
end
