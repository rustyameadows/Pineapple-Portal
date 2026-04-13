require "test_helper"

class PlanningTeamSectionTest < ActionView::TestCase
  fixtures :events, :event_team_members, :users

  setup do
    @event = events(:one)
    @segment = DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Planning Team Directory",
      source_ref: {
        "view_key" => "planning_team",
        "options" => {}
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => "planning_team",
        "label" => "Planning Team Directory"
      }
    )

    view.extend DocumentsHelper
    view.instance_variable_set(:@event, @event)
    view.instance_variable_set(:@segment, @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
    view.define_singleton_method(:inline_global_asset_data_uri) { |_asset| "data:image/png;base64,avatar" }
  end

  test "renders packet-style header and planner directory cards" do
    render template: "generated_documents/sections/planning_team", locals: { render_base_styles: false }

    assert_select ".generated-template--planning-team.generated-template--packet-sheet", count: 1
    assert_select ".generated-template__page-header-logo", count: 1
    assert_select ".generated-template__page-header-title", text: "Planning Team Directory"
    assert_select ".generated-template--planning-team__grid", count: 1
    assert_select ".generated-template--planning-team__card", minimum: 1
    assert_select ".generated-template--planning-team__name", text: "Ada Fixture"
    assert_select ".generated-template--planning-team__title", text: "Lead Planner"
    assert_no_match(/border-radius:/, rendered)
  end

  test "renders empty state when no planners are linked" do
    empty_event = events(:one)
    empty_event.planner_team_members.destroy_all
    view.instance_variable_set(:@event, empty_event)

    render template: "generated_documents/sections/planning_team", locals: { render_base_styles: false }

    assert_select ".generated-template--planning-team__empty", text: "No planners have been linked to this event yet."
  end
end
