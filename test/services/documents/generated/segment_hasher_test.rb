require "test_helper"

module Documents
  module Generated
    class SegmentHasherTest < ActiveSupport::TestCase
      setup do
        @event = events(:one)
        @source = GeneratedPacketSource.ensure_canonical!(@event, GeneratedPacketSource::CANONICAL_KEYS[:event_overview])
        @wedding_party_source = GeneratedPacketSource.ensure_canonical!(
          @event,
          GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference]
        )
        @vendor_contacts_source = GeneratedPacketSource.ensure_canonical!(
          @event,
          GeneratedPacketSource::CANONICAL_KEYS[:vendor_contacts]
        )
      end

      test "event overview hash changes when exposed event metadata changes" do
        original_hash = SegmentHasher.call(@source)

        @event.update!(
          guest_count: "220",
          social_media_policy: "Hold social posts until the first planner post.",
          parking_details: "Use the south lot."
        )

        refute_equal original_hash, SegmentHasher.call(@source)
      end

      test "event overview hash changes when planner contact fields change" do
        original_hash = SegmentHasher.call(@source)

        users(:one).update!(phone_number: "555-999-0000")

        refute_equal original_hash, SegmentHasher.call(@source)
      end

      test "event overview hash changes when vip key people change" do
        original_hash = SegmentHasher.call(@source)

        event_guests(:vip_family_primary).update!(relationship: "Lead Host")

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

      test "wedding party reference hash changes when getting ready details changes" do
        original_hash = SegmentHasher.call(@wedding_party_source)

        @event.update!(getting_ready_details: "Arrive at 8:00 AM.\n\nHair and makeup begin at 8:30 AM.")

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "wedding party reference hash changes when key people label changes" do
        original_hash = SegmentHasher.call(@wedding_party_source)

        @event.update!(key_people_label: "Family & VIPs")

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "wedding party reference hash changes when key people change" do
        original_hash = SegmentHasher.call(@wedding_party_source)

        event_guests(:vip_family_primary).update!(relationship: "Lead Host")

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "wedding party reference hash changes when key people ordering changes" do
        original_hash = SegmentHasher.call(@wedding_party_source)

        event_guests(:vip_family_primary).update!(position: 10)

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "wedding party reference hash changes when milestone transportation notes change" do
        milestone_tag = @event.run_of_show_calendar.event_calendar_tags.create!(name: "Milestones", position: 9)
        calendar_items(:ceremony).event_calendar_tags << milestone_tag
        original_hash = SegmentHasher.call(@wedding_party_source)

        calendar_items(:ceremony).update!(transportation_note: "Meet the shuttle at the east entrance.")

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "vendor contacts hash changes when planner contact fields change" do
        original_hash = SegmentHasher.call(@vendor_contacts_source)

        users(:one).update!(phone_number: "555-999-0000")

        refute_equal original_hash, SegmentHasher.call(@vendor_contacts_source)
      end

      test "vendor contacts hash changes when planner ordering changes" do
        @event.event_team_members.create!(
          user: users(:planner_two),
          member_role: EventTeamMember::TEAM_ROLES[:planner],
          lead_planner: false,
          position: 2,
          client_visible: false
        )

        original_hash = SegmentHasher.call(@vendor_contacts_source)

        event_team_members(:two).update!(position: 5)
        @event.event_team_members.find_by(user: users(:planner_two)).update!(position: 0)

        refute_equal original_hash, SegmentHasher.call(@vendor_contacts_source)
      end

      test "vendor contacts hash changes when vendor contact fields change" do
        original_hash = SegmentHasher.call(@vendor_contacts_source)

        event_vendors(:catering).update!(
          contacts_jsonb: [
            {
              name: "Maria Cater",
              title: "Account Manager",
              email: "maria@sunshine.test",
              phone: "555-999-0000",
              notes: "Updated contact"
            }
          ]
        )

        refute_equal original_hash, SegmentHasher.call(@vendor_contacts_source)
      end

      test "vendor contacts hash changes when vendor category changes" do
        original_hash = SegmentHasher.call(@vendor_contacts_source)

        event_vendors(:catering).update!(vendor_type: "Venue & Catering")

        refute_equal original_hash, SegmentHasher.call(@vendor_contacts_source)
      end

      test "vendor contacts hash changes when vendor ordering changes" do
        original_hash = SegmentHasher.call(@vendor_contacts_source)

        event_vendors(:catering).update!(position: 5)
        event_vendors(:lighting).update!(position: 0)

        refute_equal original_hash, SegmentHasher.call(@vendor_contacts_source)
      end

      test "vendor contacts hash changes when linked global vendor data changes" do
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

        original_hash = SegmentHasher.call(@vendor_contacts_source)

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

        refute_equal original_hash, SegmentHasher.call(@vendor_contacts_source)
      end
    end
  end
end
