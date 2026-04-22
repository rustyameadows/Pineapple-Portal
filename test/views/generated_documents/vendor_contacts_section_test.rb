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

  test "renders a grouped vendor contacts table and merges Pineapple cells" do
    @event.update!(
      pineapple_team_meals: "**Pineapple meals** available for *four planners*.\n\n[Meal order](https://example.com/pineapple-meals)\n\n[Unsafe](javascript:alert(1))"
    )

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
      team_meals: "**Vendor meals** available for *two staff*.\n\n[Menu](https://example.com/menu)\n\n[Unsafe](javascript:alert(1))",
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
    assert_select "table thead th", text: "Team Meals"
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
    planning_rows = fragment.css("tbody.generated-template--vendor-contacts__group").first.css("tr")
    planning_rowspan_cells = planning_rows.first.css("[rowspan]")

    assert_equal 3, fragment.css("[rowspan]").size
    assert_equal 3, planning_rowspan_cells.size
    assert planning_rowspan_cells.all? { |cell| cell["rowspan"] == planning_rows.size.to_s }
    assert_equal 2, planning_rows[1].css("td").size
    assert_equal 6, fragment.css("tbody.generated-template--vendor-contacts__group").size
    assert fragment.css(".generated-template--vendor-contacts__category--continued").any?
    assert fragment.css(".generated-template--vendor-contacts__vendor--continued").any?
    assert fragment.css(".generated-template--vendor-contacts__team-meals--continued").any?
    assert_match(/Planning Pineapple Productions Ada Fixture 555-111-2222/, rows.first.text.squish)
    assert_includes rows.first.text.squish, "Pineapple meals available for four planners."
    assert rows.map { |row| row.text.squish }.any? { |text| text.include?("Catering Sunshine Catering Maria Cater 555-123-4567") }
    assert rows.map { |row| row.text.squish }.any? { |text| text.include?("Stationery Stationery Studio Avery Ink 555-111-2222 Vendor meals available for two staff.") }
    assert fragment.css(".generated-template--vendor-contacts__team-meals").any? { |cell| cell.text.strip == "\u2014" }
    assert_select ".generated-template--vendor-contacts__team-meals strong", text: "Vendor meals"
    assert_select ".generated-template--vendor-contacts__team-meals strong", text: "Pineapple meals"
    assert_select ".generated-template--vendor-contacts__team-meals em", text: "two staff"
    assert_select ".generated-template--vendor-contacts__team-meals em", text: "four planners"
    assert_select ".generated-template--vendor-contacts__team-meals a[href='https://example.com/menu'][target='_blank'][rel='noopener noreferrer']", text: "Menu"
    assert_select ".generated-template--vendor-contacts__team-meals a[href='https://example.com/pineapple-meals'][target='_blank'][rel='noopener noreferrer']", text: "Meal order"
    assert_equal 6, fragment.css(".generated-template--vendor-contacts__team-meals p").count

    unsafe_links = fragment.css(".generated-template--vendor-contacts__team-meals a").select { |link| link.text == "Unsafe" }
    assert_equal 2, unsafe_links.size
    assert unsafe_links.all? { |link| link["href"].nil? }
  end
end
