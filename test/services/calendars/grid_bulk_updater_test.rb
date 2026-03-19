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
