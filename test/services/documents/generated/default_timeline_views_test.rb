require "test_helper"

module Documents
  module Generated
    class DefaultTimelineViewsTest < ActiveSupport::TestCase
      test "decision calendar default view uses monthly segments" do
        event = events(:two)

        view = DefaultTimelineViews.ensure_view!(event, "Decision Calendar")

        assert_equal "Decision Calendar", view.name
        assert view.monthly_segments?
      end

      test "non-decision default view uses daily segments" do
        event = events(:two)

        view = DefaultTimelineViews.ensure_view!(event, "Production Timeline")

        assert_equal "Production Timeline", view.name
        assert_equal EventCalendarView::SEGMENT_GRANULARITIES[:day], view.segment_granularity
      end
    end
  end
end
