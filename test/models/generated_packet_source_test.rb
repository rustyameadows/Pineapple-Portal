require "test_helper"

class GeneratedPacketSourceTest < ActiveSupport::TestCase
  fixtures :events

  test "ensure_canonical normalizes wedding party reference sources to the generated template" do
    event = events(:one)
    existing = event.generated_packet_sources.create!(
      source_category: GeneratedPacketSource::CATEGORIES[:canonical],
      canonical_key: GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference],
      kind: GeneratedPacketSource::KINDS[:html_view],
      title: "Wedding Party Reference",
      source_ref: {
        "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
        "options" => {
          "body_markdown" => "Legacy content"
        }
      },
      spec: {
        "kind" => GeneratedPacketSource::KINDS[:html_view],
        "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
        "label" => "Wedding Party Reference"
      }
    )

    canonical = GeneratedPacketSource.ensure_canonical!(event, :wedding_party_reference)

    assert_equal existing.id, canonical.id
    assert_equal DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY, canonical.html_view_key
    assert_equal(
      {
        "timeline_mode" => "auto",
        "timeline_tag_ids" => []
      },
      canonical.html_options
    )
  end

  test "ensure_canonical preserves shared wedding party timeline options" do
    event = events(:one)
    existing = event.generated_packet_sources.create!(
      source_category: GeneratedPacketSource::CATEGORIES[:canonical],
      canonical_key: GeneratedPacketSource::CANONICAL_KEYS[:wedding_party_reference],
      kind: GeneratedPacketSource::KINDS[:html_view],
      title: "Wedding Party Reference",
      source_ref: {
        "view_key" => DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        "options" => {
          "timeline_mode" => "manual",
          "timeline_tag_ids" => [event_calendar_tags(:vendor).id]
        }
      },
      spec: {
        "kind" => GeneratedPacketSource::KINDS[:html_view],
        "view_key" => DocumentSegment::WEDDING_PARTY_REFERENCE_VIEW_KEY,
        "label" => "Wedding Party Reference"
      }
    )

    canonical = GeneratedPacketSource.ensure_canonical!(event, :wedding_party_reference)

    assert_equal existing.id, canonical.id
    assert_equal "manual", canonical.html_options["timeline_mode"]
    assert_equal [event_calendar_tags(:vendor).id], canonical.html_options["timeline_tag_ids"]
  end

  test "ensure_canonical normalizes vendor contacts sources to the generated template" do
    event = events(:one)
    existing = event.generated_packet_sources.create!(
      source_category: GeneratedPacketSource::CATEGORIES[:canonical],
      canonical_key: GeneratedPacketSource::CANONICAL_KEYS[:vendor_contacts],
      kind: GeneratedPacketSource::KINDS[:html_view],
      title: "Vendor Contacts",
      source_ref: {
        "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
        "options" => {
          "body_markdown" => "Legacy content"
        }
      },
      spec: {
        "kind" => GeneratedPacketSource::KINDS[:html_view],
        "view_key" => DocumentSegment::TEXT_PAGE_VIEW_KEY,
        "label" => "Vendor Contacts"
      }
    )

    canonical = GeneratedPacketSource.ensure_canonical!(event, :vendor_contacts)

    assert_equal existing.id, canonical.id
    assert_equal DocumentSegment::VENDOR_CONTACTS_VIEW_KEY, canonical.html_view_key
    assert_equal({}, canonical.html_options)
  end

  test "ensure_canonical creates timeline canonicals for photo video and hair makeup" do
    event = events(:one)

    {
      photo_video_timeline: "Photo / Video Timeline",
      hair_makeup_timeline: "Hair & Makeup Timeline"
    }.each do |canonical_key, view_name|
      canonical = GeneratedPacketSource.ensure_canonical!(event, canonical_key)

      assert_equal DocumentSegment::TIMELINE_VIEW_KEY, canonical.html_view_key
      assert_equal view_name, canonical.display_title
      assert_equal true, canonical.html_options["show_location"]
      assert_equal true, canonical.html_options["show_vendor"]
      assert_equal true, canonical.html_options["show_team_members"]

      timeline_view = event.run_of_show_calendar.event_calendar_views.find(canonical.html_options["view_ref"])
      assert_equal view_name, timeline_view.name
    end
  end

  test "ensure_canonical_sources_for_event creates custom timeline canonicals" do
    event = events(:one)
    view = event_calendar_views(:vendor_view)
    canonical_key = GeneratedPacketSource.custom_timeline_canonical_key(view)

    assert_nil event.generated_packet_sources.find_by(canonical_key: canonical_key)

    GeneratedPacketSource.ensure_canonical_sources_for_event!(event)
    source = event.generated_packet_sources.find_by!(canonical_key: canonical_key)

    assert source.canonical?
    assert_equal DocumentSegment::TIMELINE_VIEW_KEY, source.html_view_key
    assert_equal "Vendor Only", source.display_title
    assert_equal view.id.to_s, source.html_options["view_ref"]
    assert_equal true, source.html_options["show_location"]
    assert_equal true, source.html_options["show_vendor"]
    assert_equal true, source.html_options["show_team_members"]
  end

  test "ensure_canonical_sources_for_event excludes default timeline views from custom canonicals" do
    event = events(:one)
    default_view = event_calendar_views(:decision_view)

    GeneratedPacketSource.ensure_canonical_sources_for_event!(event)

    assert_nil event.generated_packet_sources.find_by(canonical_key: GeneratedPacketSource.custom_timeline_canonical_key(default_view))
  end

  test "ensure_canonical_sources_for_event updates custom timeline source title while preserving display options" do
    event = events(:one)
    view = event_calendar_views(:vendor_view)

    GeneratedPacketSource.ensure_canonical_sources_for_event!(event)
    source = event.generated_packet_sources.find_by!(canonical_key: GeneratedPacketSource.custom_timeline_canonical_key(view))
    source.update!(
      source_ref: source.source_ref.deep_merge(
        "options" => {
          "show_location" => false,
          "show_vendor" => true,
          "show_team_members" => false,
          "view_ref" => view.id.to_s
        }
      )
    )

    view.update!(name: "Vendor Meals Timeline")
    GeneratedPacketSource.ensure_canonical_sources_for_event!(event)

    source.reload
    assert_equal "Vendor Meals Timeline", source.display_title
    assert_equal view.id.to_s, source.html_options["view_ref"]
    assert_equal false, source.html_options["show_location"]
    assert_equal true, source.html_options["show_vendor"]
    assert_equal false, source.html_options["show_team_members"]
  end

  test "available_canonical_sources_for_event hides stale custom timeline sources" do
    event = events(:one)
    view = event.run_of_show_calendar.event_calendar_views.create!(
      name: "Late Night Timeline",
      tag_filter: [event_calendar_tags(:vendor).id]
    )

    GeneratedPacketSource.ensure_canonical_sources_for_event!(event)
    source = event.generated_packet_sources.find_by!(canonical_key: GeneratedPacketSource.custom_timeline_canonical_key(view))

    view.destroy!

    assert event.generated_packet_sources.exists?(source.id)
    assert_not_includes GeneratedPacketSource.available_canonical_sources_for_event(event), source
  end

  test "find_or_create_group_source creates a shared group source for a group document" do
    event = events(:one)
    group_document = event.documents.create!(
      title: "Design & Decor",
      doc_kind: Document::DOC_KINDS[:generated],
      logical_id: SecureRandom.uuid,
      version: 1,
      is_latest: false,
      source: "packet",
      packet_schema_version: Document::PACKET_SCHEMA_VERSIONS[:source_backed],
      packet_container_kind: Document::PACKET_CONTAINER_KINDS[:group]
    )

    source = GeneratedPacketSource.find_or_create_group_source!(event, group_document)

    assert source.group?
    assert source.group_source?
    assert_equal group_document.logical_id, source.group_document_logical_id
    assert_equal "Design & Decor", source.display_title
  end

  test "group source validation requires a same-event group document" do
    event = events(:one)
    source = event.generated_packet_sources.new(
      source_category: GeneratedPacketSource::CATEGORIES[:group],
      kind: GeneratedPacketSource::KINDS[:group],
      title: "Missing Group",
      source_ref: { "logical_id" => SecureRandom.uuid },
      spec: { "kind" => GeneratedPacketSource::KINDS[:group] }
    )

    assert_not source.valid?
    assert_includes source.errors[:source_ref], "must reference a group in this event"
  end
end
