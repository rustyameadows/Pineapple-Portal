require "test_helper"

module Documents
  module Generated
    class SegmentHasherTest < ActiveSupport::TestCase
      setup do
        @event = events(:one)
        @source = GeneratedPacketSource.ensure_canonical!(@event, GeneratedPacketSource::CANONICAL_KEYS[:event_overview])
      end

      test "event overview hash changes when event fields change" do
        original_hash = SegmentHasher.call(@source)

        @event.update!(location: "Garden Terrace")

        refute_equal original_hash, SegmentHasher.call(@source)
      end

      test "event overview hash changes when planner contact fields change" do
        original_hash = SegmentHasher.call(@source)

        users(:one).update!(phone_number: "555-999-0000")

        refute_equal original_hash, SegmentHasher.call(@source)
      end

      test "event overview hash changes when linked global vendor data changes" do
        global_vendor = GlobalVendor.create!(
          name: "Northlight Films",
          default_vendor_type: "Photo + Video",
          default_social_handle: "northlightfilms",
          contacts_jsonb: [
            {
              "name" => "Chris Lane",
              "title" => "Producer",
              "email" => "chris@northlight.test",
              "phone" => "555-331-4400",
              "notes" => "Primary contact"
            }
          ]
        )

        @event.event_vendors.create!(
          name: "Northlight Films",
          global_vendor: global_vendor,
          contacts_jsonb: [],
          position: 8,
          client_visible: false
        )

        original_hash = SegmentHasher.call(@source)

        global_vendor.update!(
          name: "Northlight Studio",
          default_social_handle: "northlightstudio",
          contacts_jsonb: [
            {
              "name" => "Chris Lane",
              "title" => "Executive Producer",
              "email" => "hello@northlight.test",
              "phone" => "555-888-4400",
              "notes" => "Updated contact"
            }
          ]
        )

        refute_equal original_hash, SegmentHasher.call(@source)
      end
    end
  end
end
