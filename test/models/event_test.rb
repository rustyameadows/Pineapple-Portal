require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "requires a name" do
    event = Event.new
    assert_not event.valid?
    assert_includes event.errors[:name], "can't be blank"
  end

  test "planning_link_keys default to visible set" do
    event = events(:one)
    assert_equal ClientPortal::PlanningLinks.default_keys & ClientPortal::PlanningLinks.built_in_keys,
                 event.planning_link_keys
  end

  test "planning_link_enabled? reflects toggle state" do
    event = events(:one)

    assert event.planning_link_enabled?("guest_list")

    event.disable_planning_link("guest_list")
    event.save!

    refute event.planning_link_enabled?("guest_list")

    event.enable_planning_link("guest_list")
    event.save!

    assert event.planning_link_enabled?("guest_list")
  end

  test "generates a portal slug when blank" do
    event = Event.create!(name: "Slugless Event")

    assert event.portal_slug.present?
    assert_match(/\A[a-f0-9]{12}\z/, event.portal_slug)
  end

  test "keeps normalized portal slug when provided" do
    event = Event.create!(name: "Slugged Event", portal_slug: "Hello World")

    assert_equal "hello-world", event.portal_slug
  end

  test "normalizes event metadata fields" do
    event = Event.create!(
      name: "Metadata Event",
      guest_count: " 175 ",
      attire: " Black Tie ",
      style: " Elegant Garden ",
      color_palette: " Ivory, Sage, Gold ",
      social_media_policy: "  Please do not post before the planner's announcement.  ",
      parking_details: "  ",
      getting_ready_details: "\nReady room opens at 8:00 AM.\n"
    )

    assert_equal "175", event.guest_count
    assert_equal "Black Tie", event.attire
    assert_equal "Elegant Garden", event.style
    assert_equal "Ivory, Sage, Gold", event.color_palette
    assert_equal "Please do not post before the planner's announcement.", event.social_media_policy
    assert_nil event.parking_details
    assert_equal "Ready room opens at 8:00 AM.", event.getting_ready_details
  end

  test "rejects unknown planning link keys" do
    event = events(:one)
    event.planning_link_keys = %w[guest_list unknown]

    assert_not event.valid?
    assert_includes event.errors[:planning_link_keys], "contains unknown links: unknown"
  end

  test "planning link tokens include planning event links" do
    event = events(:one)
    planning_link = event_links(:planning_guestbook)

    assert_includes event.planning_link_tokens,
                    Event::PlanningLinkToken.event_link(planning_link.id),
                    "expected planning link token for custom link"
  end

  test "ordered planning link entries preserve sequence" do
    event = events(:one)
    planning_link = event_links(:planning_guestbook)

    tokens = [
      Event::PlanningLinkToken.event_link(planning_link.id),
      Event::PlanningLinkToken.built_in("guest_list")
    ]

    event.update!(planning_link_tokens: tokens)

    entries = event.ordered_planning_link_entries

    assert_equal [:event_link, :built_in], entries.map(&:kind)
    assert_equal planning_link, entries.first.record
  end

  test "move_planning_link_token reorders items" do
    event = events(:one)
    planning_link = event_links(:planning_guestbook)

    tokens = [
      Event::PlanningLinkToken.built_in("guest_list"),
      Event::PlanningLinkToken.event_link(planning_link.id)
    ]

    event.update!(planning_link_tokens: tokens)

    assert event.move_planning_link_token(Event::PlanningLinkToken.event_link(planning_link.id), :up)
    event.save!

    assert_equal Event::PlanningLinkToken.event_link(planning_link.id), event.planning_link_tokens.first
  end
end
