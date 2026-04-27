require "test_helper"

module Documents
  module Generated
    class SegmentHasherTest < ActiveSupport::TestCase
      setup do
        @event = events(:one)
        @source = GeneratedPacketSource.ensure_canonical!(@event, GeneratedPacketSource::CANONICAL_KEYS[:event_overview])
        @planning_team_source = GeneratedPacketSource.ensure_canonical!(
          @event,
          GeneratedPacketSource::CANONICAL_KEYS[:planning_team]
        )
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

      test "event overview hash changes when venue address data changes" do
        original_hash = SegmentHasher.call(@source)

        event_venues(:main_hall).update!(address: "123 Pineapple Ave\nSuite 100")

        refute_equal original_hash, SegmentHasher.call(@source)
      end

      test "event overview hash changes when milestone card fields change" do
        milestone_tag = @event.run_of_show_calendar.event_calendar_tags.create!(name: "Milestones", position: 9)
        item = calendar_items(:ceremony)
        item.event_calendar_tags << milestone_tag

        original_hash = SegmentHasher.call(@source)

        item.update!(guest_count: "150 guests")
        guest_count_hash = SegmentHasher.call(@source)
        refute_equal original_hash, guest_count_hash

        item.update!(location_name: "Updated Ballroom")
        location_hash = SegmentHasher.call(@source)
        refute_equal guest_count_hash, location_hash

        item.update!(title: "Ceremony Updated")
        title_hash = SegmentHasher.call(@source)
        refute_equal location_hash, title_hash

        item.update!(starts_at: item.starts_at + 15.minutes)
        refute_equal title_hash, SegmentHasher.call(@source)
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

      test "event overview hash ignores vendor contact changes" do
        original_hash = SegmentHasher.call(@source)

        event_vendors(:catering).update!(
          contacts_jsonb: [
            {
              name: "Maria Updated",
              title: "Senior Account Manager",
              email: "maria.updated@sunshine.test",
              phone: "555-999-0000",
              notes: "Still hidden from event overview"
            }
          ]
        )

        assert_equal original_hash, SegmentHasher.call(@source)
      end

      test "pdf asset hash changes when a newer uploaded version appears for the same logical id" do
        logical_id = SecureRandom.uuid
        pinned_document = create_uploaded_pdf(version: 1, logical_id: logical_id, title: "Ceremony Inserts")
        source = GeneratedPacketSource.find_or_create_upload_source!(@event, pinned_document, title: "Ceremony Inserts")
        original_hash = SegmentHasher.call(source)

        create_uploaded_pdf(version: 2, logical_id: logical_id, title: "Ceremony Inserts")

        refute_equal original_hash, SegmentHasher.call(source)
      end

      test "event overview hash changes when a no-contact vendor is added or renamed" do
        original_hash = SegmentHasher.call(@source)

        vendor = @event.event_vendors.create!(
          name: "No Contact Vendor",
          contacts_jsonb: [],
          position: 9,
          client_visible: false
        )

        after_create_hash = SegmentHasher.call(@source)
        refute_equal original_hash, after_create_hash

        vendor.update!(name: "No Contact Vendor Updated")

        refute_equal after_create_hash, SegmentHasher.call(@source)
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

      test "wedding party reference hash changes when a side is renamed" do
        original_hash = SegmentHasher.call(@wedding_party_source)

        event_key_person_groups(:vip_family).update!(name: "Bride's Side")

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "wedding party reference hash changes when selected timeline options change" do
        original_hash = SegmentHasher.call(@wedding_party_source)

        @wedding_party_source.assign_html_view(
          DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
          options: {
            "timeline_mode" => "manual",
            "timeline_tag_ids" => [event_calendar_tags(:vendor).id]
          }
        )
        @wedding_party_source.save!

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "wedding party reference hash changes when a tagged timeline item changes" do
        calendar_items(:ceremony).event_calendar_tags << event_calendar_tags(:wedding_party_side_a)
        original_hash = SegmentHasher.call(@wedding_party_source)

        calendar_items(:ceremony).update!(notes: "Bride arrives with bouquet and veil.")

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "wedding party reference hash changes when an item gains a selected side tag" do
        original_hash = SegmentHasher.call(@wedding_party_source)

        calendar_items(:reception).event_calendar_tags << event_calendar_tags(:wedding_party_side_a)

        refute_equal original_hash, SegmentHasher.call(@wedding_party_source)
      end

      test "timeline hash changes when the shared packet template version changes" do
        timeline_source = GeneratedPacketSource.ensure_canonical!(
          @event,
          GeneratedPacketSource::CANONICAL_KEYS[:photo_video_timeline]
        )
        original_hash = SegmentHasher.call(timeline_source)

        DocumentSegment.stub :shared_pdf_template_version, "packet-base-v999" do
          refute_equal original_hash, SegmentHasher.call(timeline_source)
        end
      end

      test "planning team hash changes when the shared packet template version changes" do
        original_hash = SegmentHasher.call(@planning_team_source)

        DocumentSegment.stub :shared_pdf_template_version, "packet-base-v999" do
          refute_equal original_hash, SegmentHasher.call(@planning_team_source)
        end
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

      test "vendor contacts hash changes when vendor team meals change" do
        original_hash = SegmentHasher.call(@vendor_contacts_source)

        event_vendors(:catering).update!(team_meals: "**Vendor meals** at 5:00 PM.")

        refute_equal original_hash, SegmentHasher.call(@vendor_contacts_source)
      end

      test "vendor contacts hash changes when pineapple team meals change" do
        original_hash = SegmentHasher.call(@vendor_contacts_source)

        @event.update!(pineapple_team_meals: "**Planner meals** at 5:00 PM.")

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

      private

      def create_uploaded_pdf(version:, logical_id:, title:)
        @event.documents.create!(
          title: title,
          doc_kind: Document::DOC_KINDS[:uploaded],
          logical_id: logical_id,
          version: version,
          is_latest: true,
          source: "staff_upload",
          storage_uri: "documents/#{logical_id}/#{version}.pdf",
          checksum: "#{logical_id}-#{version}-checksum",
          checksum_sha256: SecureRandom.hex(32),
          size_bytes: 1024,
          content_type: "application/pdf",
          built_by_user: users(:one)
        )
      end
    end
  end
end
