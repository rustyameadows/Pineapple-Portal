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
  end
end
