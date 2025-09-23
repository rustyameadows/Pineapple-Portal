require "test_helper"

module Calendars
  class ViewFilterTest < ActiveSupport::TestCase
    setup do
      @calendar = event_calendars(:run_of_show)
      @vendor_view = event_calendar_views(:vendor_view)
    end

    test "filters by tag and hides locked" do
      filter = ViewFilter.new(calendar: @calendar, view: @vendor_view)
      items = filter.items

      assert_includes items, calendar_items(:reception)
      refute_includes items, calendar_items(:ceremony)
      refute_includes items, calendar_items(:afterparty)
    end

    test "includes locked when view allows" do
      view = @vendor_view.dup
      view.hide_locked = false
      view.tag_filter = []

      filter = ViewFilter.new(calendar: @calendar, view: view)

      assert_includes filter.items, calendar_items(:afterparty)
    end
  end
end
