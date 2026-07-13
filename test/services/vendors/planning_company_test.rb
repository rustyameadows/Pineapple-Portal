require "test_helper"

module Vendors
  class PlanningCompanyTest < ActiveSupport::TestCase
    test "identifies and excludes the planning company event vendor" do
      event = events(:one)
      event_vendor = event_vendors(:pineapple_one)
      event_vendor.global_vendor.update!(name: "Renamed Planning Company")

      assert PlanningCompany.event_vendor?(event_vendor)
      assert_equal event_vendor, PlanningCompany.event_vendor_for(event)
      assert_equal event_vendor.global_vendor, PlanningCompany.global_vendor_for(event)
      assert_not_includes PlanningCompany.excluding(event.event_vendors), event_vendor
      assert_includes event.event_vendors, event_vendor
    end
  end
end
