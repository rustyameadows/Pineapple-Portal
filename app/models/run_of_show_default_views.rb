module RunOfShowDefaultViews
  # Default derived calendar views, code-only
  VIEWS = [
    {
      name: "Decision Calendar",
      tag_names: ["Decisions"],
      segment_granularity: EventCalendarView::SEGMENT_GRANULARITIES[:month]
    },
    { name: "Family Timeline", tag_names: ["Family"] },
    { name: "Photo / Video Timeline", tag_names: ["Photo / Video"] },
    { name: "Production Timeline", tag_names: ["Production"] },
    { name: "Hair & Makeup Timeline", tag_names: ["Hair & Makeup"] },
    { name: "Wedding Party Reference", tag_names: ["Wedding Party Reference"] }
  ].freeze
end
