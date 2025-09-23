require "test_helper"

module Client
  module Calendars
    class SelectedViewTest < ActiveSupport::TestCase
      setup do
        @calendar = event_calendars(:run_of_show)
        @view = event_calendar_views(:vendor_view)
      end

      test "run of show uses calendar metadata" do
        subject = SelectedView.run_of_show(@calendar)

        assert_equal @calendar.name, subject.name
        assert_equal "run-of-show", subject.slug
        assert_equal @calendar.description, subject.description
        assert_not subject.hide_locked?
      end

      test "wraps derived view attributes" do
        subject = SelectedView.new(calendar: @calendar, view: @view)

        assert_equal @view.name, subject.name
        assert_equal @view.slug, subject.slug
        assert_equal @view.description, subject.description
        assert subject.hide_locked?
        assert_equal Array(@view.tag_filter), subject.tag_filter
      end
    end
  end
end
