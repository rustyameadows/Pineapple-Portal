require "test_helper"

class GlobalVendorTest < ActiveSupport::TestCase
  test "updates no longer enqueue the broad event refresh job" do
    event = events(:one)
    global_vendor = GlobalVendor.create!(
      name: "Global Vendor",
      default_vendor_type: "Catering",
      default_social_handle: "globalvendor",
      contacts_jsonb: [
        {
          "name" => "Sam Vendor",
          "title" => "Producer",
          "email" => "sam@globalvendor.test",
          "phone" => "555-111-0000",
          "notes" => "Primary"
        }
      ]
    )

    event.event_vendors.create!(
      name: "Global Vendor",
      global_vendor: global_vendor,
      contacts_jsonb: [],
      position: 7,
      client_visible: false
    )

    enqueued_event_ids = []

    Documents::Generated::RefreshEventPacketCachesJob.stub :perform_later, ->(event_id) { enqueued_event_ids << event_id } do
      global_vendor.update!(default_social_handle: "updatedvendor")
    end

    assert_equal [], enqueued_event_ids
  end
end
