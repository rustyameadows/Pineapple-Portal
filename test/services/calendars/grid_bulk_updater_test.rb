require "test_helper"

module Calendars
  class GridBulkUpdaterTest < ActiveSupport::TestCase
    setup do
      @calendar = event_calendars(:run_of_show)
      @ceremony = calendar_items(:ceremony)
      @reception = calendar_items(:reception)
      @day_of_tag = event_calendar_tags(:day_of)
    end

    test "returns an error when no items are selected" do
      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [],
        params: {
          bulk_action: "add_tags",
          tag_ids: [@day_of_tag.id]
        }
      ).call

      assert_not result.success?
      assert_equal "Select at least one item.", result.message
    end

    test "sets vendor for selected items" do
      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id, @reception.id],
        params: {
          bulk_action: "set_vendor",
          vendor_name: "Acme Vendor"
        }
      ).call

      assert_predicate result, :success?
      assert_equal "Acme Vendor", @ceremony.reload.vendor_name
      assert_equal "Acme Vendor", @reception.reload.vendor_name
    end

    test "clears location for selected items" do
      @ceremony.update!(location_name: "Main Hall")
      @reception.update!(location_name: "Garden Terrace")

      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id, @reception.id],
        params: {
          bulk_action: "clear_location"
        }
      ).call

      assert_predicate result, :success?
      assert_nil @ceremony.reload.location_name
      assert_nil @reception.reload.location_name
    end

    test "sets time label for selected items" do
      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id, @reception.id],
        params: {
          bulk_action: "set_time_label",
          time_caption: "Morning"
        }
      ).call

      assert_predicate result, :success?
      assert_equal "Morning", @ceremony.reload.time_caption
      assert_equal "Morning", @reception.reload.time_caption
    end

    test "clears time label for selected items" do
      @ceremony.update!(time_caption: "Morning")
      @reception.update!(time_caption: "Evening")

      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id, @reception.id],
        params: {
          bulk_action: "clear_time_label"
        }
      ).call

      assert_predicate result, :success?
      assert_nil @ceremony.reload.time_caption
      assert_nil @reception.reload.time_caption
    end

    test "adds pp members to selected items" do
      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id, @reception.id],
        params: {
          bulk_action: "add_team_members",
          team_member_ids: [users(:one).id]
        }
      ).call

      assert_predicate result, :success?
      assert_includes @ceremony.reload.team_member_ids, users(:one).id
      assert_equal [users(:one).id, users(:two).id].sort, @reception.reload.team_member_ids.sort
    end

    test "removes pp members from selected items" do
      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id, @reception.id],
        params: {
          bulk_action: "remove_team_members",
          team_member_ids: [users(:one).id]
        }
      ).call

      assert_predicate result, :success?
      assert_empty @ceremony.reload.team_member_ids
      assert_equal [users(:two).id], @reception.reload.team_member_ids
    end

    test "sets other people for selected items" do
      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id, @reception.id],
        params: {
          bulk_action: "set_additional_team_members",
          additional_team_members: "DJ; Florist"
        }
      ).call

      assert_predicate result, :success?
      assert_equal "DJ; Florist", @ceremony.reload.additional_team_members
      assert_equal "DJ; Florist", @reception.reload.additional_team_members
    end

    test "clears other people for selected items" do
      @ceremony.update!(additional_team_members: "DJ")
      @reception.update!(additional_team_members: "Florist")

      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id, @reception.id],
        params: {
          bulk_action: "clear_additional_team_members"
        }
      ).call

      assert_predicate result, :success?
      assert_nil @ceremony.reload.additional_team_members
      assert_nil @reception.reload.additional_team_members
    end

    test "returns an error when setting a blank time label" do
      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id],
        params: {
          bulk_action: "set_time_label",
          time_caption: " "
        }
      ).call

      assert_not result.success?
      assert_equal "Enter a time label.", result.message
    end

    test "returns an error when no pp members are selected for add or remove" do
      add_result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id],
        params: {
          bulk_action: "add_team_members",
          team_member_ids: []
        }
      ).call

      remove_result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id],
        params: {
          bulk_action: "remove_team_members",
          team_member_ids: []
        }
      ).call

      assert_not add_result.success?
      assert_equal "Select at least one PP member.", add_result.message
      assert_not remove_result.success?
      assert_equal "Select at least one PP member.", remove_result.message
    end

    test "returns an error when setting blank other people" do
      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [@ceremony.id],
        params: {
          bulk_action: "set_additional_team_members",
          additional_team_members: " "
        }
      ).call

      assert_not result.success?
      assert_equal "Enter other people.", result.message
    end

    test "moves one same-time item up by updating position only" do
      first = create_item(title: "Load In", starts_at: Time.utc(2025, 10, 1, 12, 0), position: 10)
      second = create_item(title: "Vendor Arrival", starts_at: Time.utc(2025, 10, 1, 12, 0), position: 20)
      third = create_item(title: "Room Check", starts_at: Time.utc(2025, 10, 1, 12, 0), position: 30)
      other_time = create_item(title: "Later Check", starts_at: Time.utc(2025, 10, 1, 13, 0), position: 40)
      original_starts_at = second.starts_at

      result = CascadeScheduler.stub(:new, ->(_) { raise "scheduler should not run for same-time reorder" }) do
        GridBulkUpdater.new(
          calendar: @calendar,
          item_ids: [second.id],
          params: {
            bulk_action: "move_same_time_up",
            neighbor_item_id: first.id
          }
        ).call
      end

      assert_predicate result, :success?
      assert_equal "Order updated.", result.message
      assert_equal ["Vendor Arrival", "Load In", "Room Check"], same_time_titles("2025-10-01 12:00")
      assert_equal original_starts_at, second.reload.starts_at
      assert_equal 40, other_time.reload.position
    end

    test "moves one same-time item down by updating position only" do
      first = create_item(title: "Load In", starts_at: Time.utc(2025, 10, 1, 12, 0), position: 10)
      second = create_item(title: "Vendor Arrival", starts_at: Time.utc(2025, 10, 1, 12, 0), position: 20)

      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [first.id],
        params: {
          bulk_action: "move_same_time_down",
          neighbor_item_id: second.id
        }
      ).call

      assert_predicate result, :success?
      assert_equal ["Vendor Arrival", "Load In"], same_time_titles("2025-10-01 12:00")
    end

    test "rejects same-time reorder when multiple items are selected" do
      first = create_item(title: "Load In", starts_at: Time.utc(2025, 10, 1, 12, 0), position: 10)
      second = create_item(title: "Vendor Arrival", starts_at: Time.utc(2025, 10, 1, 12, 0), position: 20)

      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [first.id, second.id],
        params: {
          bulk_action: "move_same_time_down",
          neighbor_item_id: second.id
        }
      ).call

      assert_not result.success?
      assert_equal "Select exactly one item to move.", result.message
    end

    test "rejects same-time reorder for a different-time neighbor" do
      first = create_item(title: "Load In", starts_at: Time.utc(2025, 10, 1, 12, 0), position: 10)
      later = create_item(title: "Later Check", starts_at: Time.utc(2025, 10, 1, 13, 0), position: 20)

      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [first.id],
        params: {
          bulk_action: "move_same_time_down",
          neighbor_item_id: later.id
        }
      ).call

      assert_not result.success?
      assert_equal "Choose a neighboring item at the same time.", result.message
    end

    test "rejects same-time reorder for missing start times" do
      first = create_item(title: "Load In", starts_at: nil, position: 10)
      second = create_item(title: "Vendor Arrival", starts_at: nil, position: 20)

      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [first.id],
        params: {
          bulk_action: "move_same_time_down",
          neighbor_item_id: second.id
        }
      ).call

      assert_not result.success?
      assert_equal "Only scheduled items can be reordered within a time.", result.message
    end

    test "same-time reorder uses effective start minute for relative items" do
      anchor = create_item(title: "Anchor", starts_at: Time.utc(2025, 10, 1, 12, 0), duration_minutes: 30, position: 10)
      relative = create_item(
        title: "Relative Cue",
        starts_at: nil,
        relative_anchor: anchor,
        relative_offset_minutes: 0,
        position: 20
      )

      result = GridBulkUpdater.new(
        calendar: @calendar,
        item_ids: [relative.id],
        params: {
          bulk_action: "move_same_time_up",
          neighbor_item_id: anchor.id
        }
      ).call

      assert_predicate result, :success?
      assert_equal ["Relative Cue", "Anchor"], same_time_titles("2025-10-01 12:00")
    end

    test "deletes selected items and reruns scheduler once" do
      scheduler = Minitest::Mock.new
      scheduler.expect(:call, true)

      result = CascadeScheduler.stub(:new, ->(calendar) {
        assert_equal @calendar, calendar
        scheduler
      }) do
        assert_difference("CalendarItem.count", -2) do
          GridBulkUpdater.new(
            calendar: @calendar,
            item_ids: [@ceremony.id, @reception.id],
            params: {
              bulk_action: "delete_items"
            }
          ).call
        end
      end

      scheduler.verify
      assert_predicate result, :success?
      assert_equal "2 items removed.", result.message
    end

    private

    def create_item(title:, starts_at:, position:, duration_minutes: 30, relative_anchor: nil, relative_offset_minutes: 0)
      @calendar.calendar_items.create!(
        title: title,
        starts_at: starts_at,
        duration_minutes: duration_minutes,
        relative_anchor: relative_anchor,
        relative_offset_minutes: relative_offset_minutes,
        position: position
      )
    end

    def same_time_titles(time)
      minute = Time.zone.parse(time).utc
      @calendar.calendar_items.to_a
               .select { |item| item.effective_starts_at&.utc&.change(sec: 0) == minute }
               .sort_by { |item| [item.position.to_i, item.title.to_s.downcase, item.id.to_i] }
               .map(&:title)
    end
  end
end
