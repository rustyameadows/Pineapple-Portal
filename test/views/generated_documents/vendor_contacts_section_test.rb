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
  end

  test "renders a grouped vendor contacts table with category and vendor rowspans" do
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

    render template: "generated_documents/sections/vendor_contacts", locals: { render_base_styles: false }

    fragment = Nokogiri::HTML.fragment(rendered)
    rows = fragment.css("table tbody tr")
    row_text = rows.map { |row| row.text.squish }
    pineapple_vendor_cell = rows.first.at_css("td.generated-template--vendor-contacts__vendor")
    pineapple_category_cell = rows.first.at_css("td.generated-template--vendor-contacts__category")
    stationery_row = rows[5]

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
    assert_equal "Planning", pineapple_category_cell.text.strip
    assert_equal "3", pineapple_category_cell["rowspan"]
    assert_equal "Pineapple Productions", pineapple_vendor_cell.text.strip
    assert_equal "3", pineapple_vendor_cell["rowspan"]
    assert_equal "Stationery", stationery_row.at_css("td.generated-template--vendor-contacts__category").text.strip
    assert_equal "2", stationery_row.at_css("td.generated-template--vendor-contacts__category")["rowspan"]
    assert_equal "Stationery Studio", stationery_row.at_css("td.generated-template--vendor-contacts__vendor").text.strip
    assert_equal "2", stationery_row.at_css("td.generated-template--vendor-contacts__vendor")["rowspan"]
    assert_match(/Planning Pineapple Productions Ada Fixture 555-111-2222/, row_text[0])
    assert_match(/Catering Sunshine Catering Maria Cater 555-123-4567/, row_text[3])
    assert_match(/Stationery Stationery Studio Avery Ink 555-111-2222/, row_text[5])
  end
end
