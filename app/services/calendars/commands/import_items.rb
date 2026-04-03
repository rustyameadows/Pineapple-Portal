module Calendars
  module Commands
    class ImportItems
      InvalidSource = Calendars::ImportProjection::InvalidSource
      InvalidSelection = Calendars::ImportProjection::InvalidSelection

      Result = Struct.new(
        :imported_count,
        :fallback_to_absolute_count,
        :missing_time_count,
        :created_tag_count,
        :batch_tag_name,
        keyword_init: true
      )

      def initialize(destination_event:, destination_calendar:, source_event:, source_timeline_ref:, selection_mode:, selected_item_ids: [], anchor_date: nil, batch_tag_enabled: false)
        @destination_event = destination_event
        @destination_calendar = destination_calendar
        @source_event = source_event
        @source_timeline_ref = source_timeline_ref.to_s
        @selection_mode = selection_mode.to_s
        @selected_item_ids = Array(selected_item_ids).map(&:to_i).reject(&:zero?)
        @anchor_date = anchor_date
        @batch_tag_enabled = ActiveModel::Type::Boolean.new.cast(batch_tag_enabled)
      end

      def call
        projection = Calendars::ImportProjection.new(
          destination_event: destination_event,
          destination_calendar: destination_calendar,
          source_event: source_event,
          source_timeline_ref: source_timeline_ref,
          selection_mode: selection_mode,
          selected_item_ids: selected_item_ids,
          anchor_date: anchor_date,
          batch_tag_enabled: batch_tag_enabled
        ).call

        selected_source_items = projection.selected_source_items
        raise InvalidSelection, "Choose an anchor date to import around." if projection.anchor_date_missing
        raise InvalidSelection, "No items matched the selected import options." if selected_source_items.empty?

        plans_by_source_id = projection.item_plans.index_by { |plan| plan.source_item.id }
        destination_tag_map = build_destination_tag_map
        next_position = destination_calendar.calendar_items.maximum(:position).to_i
        source_to_imported = {}
        created_tag_count = 0
        batch_tag = nil

        ActiveRecord::Base.transaction do
          batch_tag = ensure_batch_tag! if batch_tag_enabled
          created_tag_count += 1 if batch_tag

          selected_source_items.each do |source_item|
            next_position += 1
            plan = plans_by_source_id.fetch(source_item.id)
            attrs = plan.import_attributes.merge(position: next_position)
            source_to_imported[source_item.id] = destination_calendar.calendar_items.create!(attrs)
          end

          selected_source_items.each do |source_item|
            next unless source_item.relative?

            imported_item = source_to_imported[source_item.id]
            imported_anchor = source_to_imported[source_item.relative_anchor_id]
            next unless imported_item && imported_anchor

            imported_item.update!(relative_anchor: imported_anchor)
          end

          selected_source_items.each do |source_item|
            imported_item = source_to_imported.fetch(source_item.id)
            tag_result = sync_tags_for_item(
              source_item: source_item,
              imported_item: imported_item,
              destination_tag_map: destination_tag_map,
              batch_tag: batch_tag
            )
            created_tag_count += tag_result[:created_count]
          end

          Calendars::CascadeScheduler.new(destination_calendar).call
        end

        Result.new(
          imported_count: selected_source_items.size,
          fallback_to_absolute_count: projection.fallback_to_absolute_count,
          missing_time_count: projection.missing_time_count,
          created_tag_count: created_tag_count,
          batch_tag_name: batch_tag&.name
        )
      end

      private

      attr_reader :destination_event,
                  :destination_calendar,
                  :source_event,
                  :source_timeline_ref,
                  :selection_mode,
                  :selected_item_ids,
                  :anchor_date,
                  :batch_tag_enabled

      def sync_tags_for_item(source_item:, imported_item:, destination_tag_map:, batch_tag:)
        created_count = 0
        destination_tag_ids = source_item.event_calendar_tags.map do |source_tag|
          name = source_tag.name.to_s.strip
          next if name.blank?

          key = name.downcase
          destination_tag = destination_tag_map[key]
          unless destination_tag
            destination_tag = destination_calendar.event_calendar_tags.create!(
              name: name,
              color_token: source_tag.color_token
            )
            destination_tag_map[key] = destination_tag
            created_count += 1
          end
          destination_tag.id
        end.compact.uniq

        destination_tag_ids << batch_tag.id if batch_tag
        imported_item.event_calendar_tag_ids = destination_tag_ids.uniq
        { created_count: created_count }
      end

      def build_destination_tag_map
        destination_calendar.event_calendar_tags.each_with_object({}) do |tag, map|
          key = tag.name.to_s.strip.downcase
          next if key.blank?

          map[key] = tag
        end
      end

      def ensure_batch_tag!
        batch_tag_name = Calendars::ImportProjection.next_batch_tag_name(destination_calendar.event_calendar_tags.lock.pluck(:name))
        destination_calendar.event_calendar_tags.create!(
          name: batch_tag_name,
          color_token: Calendars::ImportProjection::BATCH_TAG_COLOR
        )
      end
    end
  end
end
