require "test_helper"

module Calendars
  module Commands
    class ImportItemsTest < ActiveSupport::TestCase
      setup do
        @source_event = events(:one)
        @source_calendar = event_calendars(:run_of_show)
        @destination_event = events(:two)
        @destination_calendar = @destination_event.event_calendars.create!(
          name: "Run of Show",
          timezone: "UTC"
        )
      end

      test "copies allowed fields and resets forbidden fields" do
        source_item = @source_calendar.calendar_items.create!(
          title: "Source Kickoff",
          notes: "Bring all departments together.",
          duration_minutes: 75,
          starts_at: Time.utc(2025, 10, 1, 13, 0, 0),
          status: CalendarItem::STATUSES[:completed],
          locked: true,
          vendor_name: "Acme Vendor",
          location_name: "Garden Room",
          additional_team_members: "Temp contractor",
          time_caption: "Doors open",
          position: next_source_position
        )
        source_item.team_member_ids = [users(:one).id, users(:two).id]

        tag = @source_calendar.event_calendar_tags.create!(name: "Logistics", color_token: "sky")
        source_item.event_calendar_tags << tag

        result = import_items(selected_item_ids: [source_item.id])
        imported = @destination_calendar.calendar_items.find_by!(title: "Source Kickoff")

        assert_equal 1, result.imported_count
        assert_equal source_item.notes, imported.notes
        assert_equal source_item.duration_minutes, imported.duration_minutes
        assert_equal source_item.time_caption, imported.time_caption
        assert_equal CalendarItem::STATUSES[:planned], imported.status
        assert_equal false, imported.locked?
        assert_nil imported.vendor_name
        assert_nil imported.location_name
        assert_nil imported.additional_team_members
        assert_equal [], imported.team_member_ids
      end

      test "preserves relative links when anchor is imported" do
        source_anchor = calendar_items(:ceremony)
        source_dependent = calendar_items(:reception)

        result = import_items(selected_item_ids: [source_anchor.id, source_dependent.id])
        imported_anchor = @destination_calendar.calendar_items.find_by!(title: source_anchor.title)
        imported_dependent = @destination_calendar.calendar_items.find_by!(title: source_dependent.title)

        assert_equal 2, result.imported_count
        assert_equal 0, result.fallback_to_absolute_count
        assert_equal imported_anchor.id, imported_dependent.relative_anchor_id
        assert_equal source_dependent.relative_offset_minutes, imported_dependent.relative_offset_minutes
        assert_equal source_dependent.relative_before?, imported_dependent.relative_before?
        assert_equal source_dependent.relative_to_anchor_end?, imported_dependent.relative_to_anchor_end?
      end

      test "preserved relative items keep their shifted scheduled times after cascade scheduling" do
        source_anchor = calendar_items(:ceremony)
        source_dependent = calendar_items(:reception)
        custom_anchor_date = Date.new(2025, 11, 20)

        import_items(
          selected_item_ids: [source_anchor.id, source_dependent.id],
          anchor_date: custom_anchor_date
        )
        imported_anchor = @destination_calendar.calendar_items.find_by!(title: source_anchor.title)
        imported_dependent = @destination_calendar.calendar_items.find_by!(title: source_dependent.title)

        assert_in_delta shifted_time(source_anchor.starts_at, anchor_date: custom_anchor_date), imported_anchor.starts_at, 1
        assert_in_delta shifted_time(source_dependent.effective_starts_at, anchor_date: custom_anchor_date), imported_dependent.starts_at, 1
        assert_in_delta shifted_time(source_dependent.effective_ends_at, anchor_date: custom_anchor_date), imported_dependent.effective_ends_at, 1
      end

      test "preserves relative before anchor end rules" do
        source_anchor = calendar_items(:ceremony)
        source_item = @source_calendar.calendar_items.create!(
          title: "Mic check",
          relative_anchor: source_anchor,
          relative_offset_minutes: 15,
          relative_before: true,
          relative_to_anchor_end: true,
          duration_minutes: 20,
          position: next_source_position
        )
        custom_anchor_date = Date.new(2025, 11, 20)

        import_items(
          selected_item_ids: [source_anchor.id, source_item.id],
          anchor_date: custom_anchor_date
        )
        imported_item = @destination_calendar.calendar_items.find_by!(title: source_item.title)

        assert imported_item.relative_before?
        assert imported_item.relative_to_anchor_end?
        assert_in_delta shifted_time(source_item.effective_starts_at, anchor_date: custom_anchor_date), imported_item.starts_at, 1
      end

      test "falls back to absolute when relative anchor is not imported" do
        source_item = calendar_items(:reception)
        result = import_items(selected_item_ids: [source_item.id])
        imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)
        expected_start = shifted_time(source_item.effective_starts_at)

        assert_equal 1, result.imported_count
        assert_equal 1, result.fallback_to_absolute_count
        assert_nil imported.relative_anchor_id
        assert_equal 0, imported.relative_offset_minutes
        assert_equal false, imported.relative_before?
        assert_equal false, imported.relative_to_anchor_end?
        assert_in_delta expected_start, imported.starts_at, 1
      end

      test "keeps descendants relative when their imported parent falls back to absolute" do
        source_parent = calendar_items(:reception)
        source_child = calendar_items(:afterparty)

        result = import_items(selected_item_ids: [source_parent.id, source_child.id])
        imported_parent = @destination_calendar.calendar_items.find_by!(title: source_parent.title)
        imported_child = @destination_calendar.calendar_items.find_by!(title: source_child.title)

        assert_equal 1, result.fallback_to_absolute_count
        assert_nil imported_parent.relative_anchor_id
        assert_equal imported_parent.id, imported_child.relative_anchor_id
        assert_in_delta shifted_time(source_parent.effective_starts_at), imported_parent.starts_at, 1
        assert_equal false, imported_child.locked?
        assert_in_delta imported_parent.starts_at + source_child.relative_offset_minutes.minutes, imported_child.starts_at, 1
      end

      test "shifts absolute times by event start-date delta" do
        source_item = calendar_items(:ceremony)
        import_items(selected_item_ids: [source_item.id])
        imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)

        assert_in_delta shifted_time(source_item.starts_at), imported.starts_at, 1
      end

      test "shifts absolute times by custom anchor date" do
        source_item = calendar_items(:ceremony)
        custom_anchor_date = Date.new(2025, 11, 20)
        import_items(selected_item_ids: [source_item.id], anchor_date: custom_anchor_date)
        imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)

        assert_in_delta shifted_time(source_item.starts_at, anchor_date: custom_anchor_date), imported.starts_at, 1
      end

      test "preserves the destination local clock time across daylight saving boundaries" do
        @destination_calendar.update!(timezone: "America/New_York")
        source_item = calendar_items(:ceremony)
        custom_anchor_date = Date.new(2025, 11, 20)

        import_items(selected_item_ids: [source_item.id], anchor_date: custom_anchor_date)
        imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)

        expected = ActiveSupport::TimeZone["America/New_York"].local(2025, 11, 20, 11, 0, 0).utc
        assert_in_delta expected, imported.starts_at, 1
      end

      test "maps existing tags and creates missing tags by name" do
        source_item = calendar_items(:reception)
        source_new_tag = @source_calendar.event_calendar_tags.create!(name: "Logistics", color_token: "forest")
        source_item.event_calendar_tags << source_new_tag
        existing_destination_tag = @destination_calendar.event_calendar_tags.create!(name: "vendor", color_token: "amber")

        result = import_items(selected_item_ids: [source_item.id])
        imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)
        destination_new_tag = @destination_calendar.event_calendar_tags.find_by!(name: "Logistics")

        assert_equal 1, result.created_tag_count
        assert_includes imported.event_calendar_tag_ids, existing_destination_tag.id
        assert_includes imported.event_calendar_tag_ids, destination_new_tag.id
        assert_equal "forest", destination_new_tag.color_token
      end

      test "handles missing effective start time in fallback mode" do
        source_anchor = @source_calendar.calendar_items.create!(
          title: "Unscheduled anchor",
          starts_at: nil,
          duration_minutes: 45,
          position: next_source_position
        )
        source_item = @source_calendar.calendar_items.create!(
          title: "Dependent item",
          relative_anchor: source_anchor,
          relative_offset_minutes: 30,
          position: next_source_position
        )

        result = import_items(selected_item_ids: [source_item.id])
        imported = @destination_calendar.calendar_items.find_by!(title: "Dependent item")

        assert_equal 1, result.fallback_to_absolute_count
        assert_equal 1, result.missing_time_count
        assert_nil imported.starts_at
        assert_nil imported.relative_anchor_id
      end

      test "handles missing start time for unscheduled absolute items" do
        source_item = @source_calendar.calendar_items.create!(
          title: "Unscheduled absolute",
          starts_at: nil,
          duration_minutes: 30,
          position: next_source_position
        )

        result = import_items(selected_item_ids: [source_item.id])
        imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)

        assert_equal 1, result.missing_time_count
        assert_nil imported.starts_at
        assert_nil imported.relative_anchor_id
      end

      test "imports all items from a filtered timeline view in all mode" do
        vendor_view = event_calendar_views(:vendor_view)

        result = import_items(
          source_timeline_ref: "view:#{vendor_view.id}",
          selection_mode: "all",
          selected_item_ids: []
        )

        assert_equal 1, result.imported_count
        assert_equal ["Reception"], @destination_calendar.calendar_items.order(:position).pluck(:title)
      end

      test "does not shift imported times when the source event has no start date" do
        source_event = Event.create!(name: "Floating source")
        source_calendar = source_event.event_calendars.create!(name: "Run of Show", timezone: "UTC")
        source_item = source_calendar.calendar_items.create!(
          title: "Loose schedule",
          starts_at: Time.utc(2025, 12, 1, 9, 0, 0),
          duration_minutes: 30,
          position: 0
        )

        result = ImportItems.new(
          destination_event: @destination_event,
          destination_calendar: @destination_calendar,
          source_event: source_event,
          source_timeline_ref: "run_of_show",
          selection_mode: "selected",
          selected_item_ids: [source_item.id],
          anchor_date: Date.new(2026, 1, 5),
          batch_tag_enabled: false
        ).call
        imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)

        assert_equal 1, result.imported_count
        assert_in_delta source_item.starts_at, imported.starts_at, 1
      end

      test "does not create a batch tag when batch tagging is disabled" do
        source_item = calendar_items(:ceremony)

        result = import_items(selected_item_ids: [source_item.id], batch_tag_enabled: false)
        imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)

        assert_nil result.batch_tag_name
        assert_empty imported.event_calendar_tags.where("lower(name) LIKE ?", "imported%")
      end

      test "creates incremented batch tags across import rounds when enabled" do
        source_item = calendar_items(:ceremony)

        first_result = import_items(selected_item_ids: [source_item.id], batch_tag_enabled: true)
        first_imported = @destination_calendar.calendar_items.find_by!(title: source_item.title)

        assert_equal "imported", first_result.batch_tag_name
        assert_includes first_imported.event_calendar_tags.pluck(:name), "imported"

        second_source_item = calendar_items(:decision_flowers)
        second_result = import_items(selected_item_ids: [second_source_item.id], batch_tag_enabled: true)
        second_imported = @destination_calendar.calendar_items.find_by!(title: second_source_item.title)

        assert_equal "imported-2", second_result.batch_tag_name
        assert_includes second_imported.event_calendar_tags.pluck(:name), "imported-2"
      end

      test "applies the batch tag to every imported item and counts created tags accurately" do
        source_anchor = calendar_items(:ceremony)
        source_dependent = calendar_items(:reception)

        result = import_items(
          selected_item_ids: [source_anchor.id, source_dependent.id],
          batch_tag_enabled: true
        )
        batch_tag = @destination_calendar.event_calendar_tags.find_by!(name: "imported")

        assert_equal "slategray", batch_tag.color_token
        assert_equal 2, result.created_tag_count
        @destination_calendar.calendar_items.each do |item|
          assert_includes item.event_calendar_tags.pluck(:name), "imported"
        end
      end

      private

      def import_items(source_timeline_ref: "run_of_show", selection_mode: "selected", selected_item_ids: [], anchor_date: @destination_event.starts_on, batch_tag_enabled: false)
        ImportItems.new(
          destination_event: @destination_event,
          destination_calendar: @destination_calendar,
          source_event: @source_event,
          source_timeline_ref: source_timeline_ref,
          selection_mode: selection_mode,
          selected_item_ids: selected_item_ids,
          anchor_date: anchor_date,
          batch_tag_enabled: batch_tag_enabled
        ).call
      end

      def shifted_time(time_value, anchor_date: @destination_event.starts_on)
        return nil if time_value.blank?

        shift_minutes = ((anchor_date - @source_event.starts_on).to_i * 24 * 60)
        time_value + shift_minutes.minutes
      end

      def next_source_position
        @source_calendar.calendar_items.maximum(:position).to_i + 1
      end
    end
  end
end
