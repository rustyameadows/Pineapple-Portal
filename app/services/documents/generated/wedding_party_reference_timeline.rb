require "set"

module Documents
  module Generated
    class WeddingPartyReferenceTimeline
      MAX_MANUAL_COLUMNS = 4

      def initialize(event:, options: {})
        @event = event
        @options = GeneratedPacketSource.default_wedding_party_reference_options.deep_merge(
          normalize_options(options)
        )
      end

      def call
        columns = selected_columns

        return {
          timezone: timezone,
          columns: [],
          day_groups: [],
          show_day_headers: false,
          empty_message: empty_message
        } if columns.empty?

        day_groups = build_day_groups(columns)

        {
          timezone: timezone,
          columns: columns,
          day_groups: day_groups,
          show_day_headers: day_groups.size > 1,
          empty_message: nil
        }
      end

      private

      attr_reader :event, :options

      def normalize_options(options)
        return {} unless options.respond_to?(:to_h)

        options.to_h.stringify_keys.slice("timeline_mode", "timeline_tag_ids")
      end

      def calendar
        @calendar ||= event.run_of_show_calendar
      end

      def timezone
        calendar&.timezone.presence || Time.zone.name
      end

      def selected_columns
        @selected_columns ||= begin
          columns = if manual_mode?
                      manual_columns.presence || auto_columns
                    else
                      auto_columns
                    end

          columns.first(MAX_MANUAL_COLUMNS)
        end
      end

      def manual_mode?
        options["timeline_mode"].to_s == "manual"
      end

      def auto_columns
        key_person_groups.first(2).filter_map do |group|
          build_column(group.event_calendar_tag)
        end
      end

      def manual_columns
        Array(options["timeline_tag_ids"]).map(&:to_i).reject(&:zero?).uniq.filter_map do |tag_id|
          build_column(available_tags_by_id[tag_id])
        end
      end

      def build_column(tag)
        return if tag.blank?

        group = tag.event_key_person_group

        {
          tag_id: tag.id,
          tag_name: tag.name,
          group_id: group&.id,
          header: group&.name.to_s.strip.presence || tag.name
        }
      end

      def key_person_groups
        @key_person_groups ||= event.event_key_person_groups.includes(:event_calendar_tag).ordered.to_a
      end

      def available_tags_by_id
        @available_tags_by_id ||= begin
          tags = if calendar
                   calendar.event_calendar_tags.includes(:event_key_person_group).order(:position, :name).to_a
                 else
                   []
                 end

          tags.index_by(&:id)
        end
      end

      def sorted_calendar_items
        @sorted_calendar_items ||= begin
          return [] unless calendar

          Calendars::TimelineOrder.sort(
            calendar.calendar_items.includes(:event_calendar_tags, :relative_anchor).to_a,
            timezone: timezone
          )
        end
      end

      def build_day_groups(columns)
        selected_tag_ids = columns.map { |column| column[:tag_id] }.to_set
        items_by_tag_id = Hash.new { |hash, key| hash[key] = [] }

        sorted_calendar_items.each do |item|
          matching_tag_ids = item.event_calendar_tags.map(&:id).select { |tag_id| selected_tag_ids.include?(tag_id) }
          next if matching_tag_ids.empty?

          matching_tag_ids.each do |tag_id|
            items_by_tag_id[tag_id] << item
          end
        end

        buckets = ordered_day_buckets(items_by_tag_id.values.flatten.uniq)
        buckets = [nil] if buckets.empty?

        buckets.map do |bucket|
          day_columns = columns.map do |column|
            items = Array(items_by_tag_id[column[:tag_id]]).select { |item| day_bucket_for(item) == bucket }

            column.merge(items: items)
          end

          {
            date_label: bucket&.fetch(:label, nil),
            columns: day_columns,
            column_groups: day_columns.each_slice(2).map { |column_pair| build_column_group(column_pair) }
          }
        end
      end

      def build_column_group(column_pair)
        grouped_items = column_pair.to_h do |column|
          [column[:tag_id], column[:items].group_by { |item| alignment_key_for(item) }]
        end

        alignment_keys = grouped_items.values.flat_map(&:keys).uniq.sort_by { |key| alignment_sort_key(key) }

        {
          columns: column_pair,
          rows: alignment_keys.flat_map do |alignment_key|
            max_items_for_key = column_pair.map do |column|
              Array(grouped_items.dig(column[:tag_id], alignment_key)).size
            end.max.to_i

            max_items_for_key.times.map do |index|
              {
                alignment_key: alignment_key,
                cells: column_pair.map do |column|
                  {
                    column: column,
                    item: Array(grouped_items.dig(column[:tag_id], alignment_key))[index]
                  }
                end
              }
            end
          end
        }
      end

      def alignment_key_for(item)
        start_time = Calendars::TimelineOrder.start_minute(item, timezone: timezone)
        return ["time", start_time.to_i] if start_time

        ["item", item.title.to_s.downcase, item.id.to_i]
      end

      def alignment_sort_key(key)
        key.first == "time" ? [0, key.second] : [1, key.second, key.third]
      end

      def ordered_day_buckets(items)
        items.filter_map { |item| day_bucket_for(item) }.uniq.sort_by { |bucket| bucket[:sort_key] || Float::INFINITY }
      end

      def day_bucket_for(item)
        start_time = item.effective_starts_at&.in_time_zone(timezone)
        return { sort_key: nil, label: "Date TBD" } unless start_time

        {
          sort_key: start_time.to_date.jd,
          label: start_time.strftime("%A, %B %-d")
        }
      end

      def empty_message
        if manual_mode?
          return "Run-of-show calendar is not available yet." if calendar.blank?

          "Select at least one timeline tag to show wedding party items."
        else
          return "Create a key-person side to show an automatic wedding party timeline column." if key_person_groups.empty?
          return "Run-of-show calendar is not available yet." if calendar.blank?

          "No wedding party timeline columns are configured yet."
        end
      end
    end
  end
end
