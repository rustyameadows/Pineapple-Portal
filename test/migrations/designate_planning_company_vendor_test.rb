require "test_helper"
require Rails.root.join("db/migrate/20260709170000_designate_planning_company_vendor")

class DesignatePlanningCompanyVendorTest < ActiveSupport::TestCase
  test "backfill links the planning company to existing events without changing planner data" do
    event = events(:two)
    planning_company = global_vendors(:pineapple_productions)
    planner_member_ids = event.planner_team_member_ids
    event.update!(pineapple_team_meals: "Keep these planner meal notes")
    event_vendors(:pineapple_two).delete

    DesignatePlanningCompanyVendor::EventVendorBackfill.new(planning_company).call

    event_vendor = event.event_vendors.find_by!(global_vendor: planning_company)
    assert_not event_vendor.client_visible?
    assert_nil event_vendor.team_meals
    assert_empty event_vendor.selected_contacts
    assert_equal "Keep these planner meal notes", event.reload.pineapple_team_meals
    assert_equal planner_member_ids, event.planner_team_member_ids
  end

  test "backfill preserves an existing planning company event vendor" do
    planning_company = global_vendors(:pineapple_productions)
    existing = event_vendors(:pineapple_one)
    existing.update!(position: 27)

    assert_no_changes -> { existing.reload.updated_at } do
      DesignatePlanningCompanyVendor::EventVendorBackfill.new(planning_company).call
    end

    assert_equal 27, existing.reload.position
  end
end
