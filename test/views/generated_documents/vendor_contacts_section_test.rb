require "test_helper"

class VendorContactsSectionTest < ActionView::TestCase
  fixtures :events, :event_team_members, :event_vendors, :users

  setup do
    @event = events(:one)
    @segment = DocumentSegment.new(
      kind: DocumentSegment::KINDS[:html_view],
      title: "Vendor Contacts",
      source_ref: {
        "view_key" => DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
        "options" => {}
      },
      spec: {
        "kind" => DocumentSegment::KINDS[:html_view],
        "view_key" => DocumentSegment::VENDOR_CONTACTS_VIEW_KEY,
        "label" => "Vendor Contacts"
      }
    )

    view.extend DocumentsHelper
    view.extend GeneratedDocumentsHelper
    view.instance_variable_set(:@event, @event)
    view.instance_variable_set(:@segment, @segment)
    view.define_singleton_method(:inline_asset_data_uri) { |_path| "data:image/png;base64,stub" }
    view.define_singleton_method(:inline_font_asset_data_uri) { |_path| "data:font/woff2;base64,stub" }
  end

  test "renders a grouped vendor contacts table without rowspans and keeps inherited contacts" do
    @event.event_team_members.create!(
      user: users(:planner_two),
      member_role: EventTeamMember::TEAM_ROLES[:planner],
      lead_planner: false,
      position: 2,
      client_visible: false
    )

    @event.event_vendors.create!(
      name: "Stationery Studio",
      vendor_type: "Stationery",
      social_handle: "@stationerystudio",
      contacts_jsonb: [
        { name: "Avery Ink", phone: "555-111-2222" },
        { title: "On-Site Contact", phone: "555-222-3333" }
      ],
      position: 9,
      client_visible: false
    )

    @event.event_vendors.create!(
      name: "Silent Vendor",
      vendor_type: "Lighting",
      contacts_jsonb: [],
      position: 10,
      client_visible: false
    )

    inherited_vendor = GlobalVendor.create!(
      name: "House Band",
      contacts_jsonb: [
        { name: "Ivy Sound", phone: "555-333-4444" }
      ]
    )

    @event.event_vendors.create!(
      global_vendor: inherited_vendor,
      vendor_type: "Entertainment",
      contacts_jsonb: [],
      position: 11,
      client_visible: false
    )

    render template: "generated_documents/sections/vendor_contacts", locals: { render_base_styles: false }

    fragment = Nokogiri::HTML.fragment(rendered)
    rows = fragment.css("table tbody tr")

    assert_select ".generated-template--vendor-contacts", count: 1
    assert_select ".generated-template__page-header-title", text: "Vendor Contacts"
    assert_select "table thead th", text: "Category"
    assert_select "table thead th", text: "Vendor"
    assert_select "table thead th", text: "Contact"
    assert_select "table thead th", text: "Phone"
    assert_select "table tbody tr td", text: "Planning", count: 1
    assert_select "table tbody tr td", text: "Catering", count: 1
    assert_select "table tbody tr td", text: "Lighting", count: 2
    assert_select "table tbody tr td", text: "Stationery", count: 1
    assert_select "table tbody tr td", text: "Pineapple Productions", count: 1
    assert_select "table tbody tr td", text: "Ada Fixture", count: 1
    assert_select "table tbody tr td", text: "Grace Fixture", count: 1
    assert_select "table tbody tr td", text: "Brooke Planner", count: 1
    assert_select "table tbody tr td", text: "Sunshine Catering", count: 1
    assert_select "table tbody tr td", text: "Bright Lights Production", count: 1
    assert_select "table tbody tr td", text: "Stationery Studio", count: 1
    assert_select "table tbody tr td", text: "Silent Vendor", count: 1
    assert_select "table tbody tr td", text: "House Band", count: 1
    assert_select "table tbody tr td", text: "Ivy Sound", count: 1
    assert_equal 9, rows.count
    assert_empty fragment.css("[rowspan]")
    assert_equal 6, fragment.css("tbody.generated-template--vendor-contacts__group").size
    assert fragment.css(".generated-template--vendor-contacts__category--continued").any?
    assert fragment.css(".generated-template--vendor-contacts__vendor--continued").any?
    assert_match(/Planning Pineapple Productions Ada Fixture 555-111-2222/, rows.first.text.squish)
    assert_includes rows.map { |row| row.text.squish }, "Catering Sunshine Catering Maria Cater 555-123-4567"
    assert_includes rows.map { |row| row.text.squish }, "Stationery Stationery Studio Avery Ink 555-111-2222"
  end
end
