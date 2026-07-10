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

  test "renders a grouped vendor contacts table and merges every vendor group" do
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

    create_event_vendor(
      name: "Stationery Studio",
      vendor_type: "Stationery",
      social_handle: "@stationerystudio",
      contacts: [
        { name: "Avery Ink", phone: "555-111-2222" },
        { title: "On-Site Contact", phone: "555-222-3333" }
      ],
      team_meals: "**Vendor meals** available for *two staff*.\n\n[Menu](https://example.com/menu)\n\n[Unsafe](javascript:alert(1))",
      position: 9,
      client_visible: false
    )

    create_event_vendor(
      name: "Silent Vendor",
      vendor_type: "Lighting",
      contacts: [],
      position: 10,
      client_visible: false
    )

    inherited_vendor = GlobalVendor.create!(
      name: "House Band",
      contacts_attributes: [
        { name: "Ivy Sound", phone: "555-333-4444" },
        { name: "Unselected Band Manager", phone: "555-000-0000" }
      ]
    )

    house_band = @event.event_vendors.create!(
      global_vendor: inherited_vendor,
      vendor_type: "Entertainment",
      position: 11,
      client_visible: false
    )
    house_band.replace_contact_ids!([ inherited_vendor.contacts.first.id ])

    render template: "generated_documents/sections/vendor_contacts", locals: { render_base_styles: false }

    fragment = Nokogiri::HTML.fragment(rendered)
    rows = fragment.css("table.generated-template--vendor-contacts__table > tbody.generated-template--vendor-contacts__group > tr")

    assert_select ".generated-template--vendor-contacts", count: 1
    assert_select ".generated-template__page-header-title", text: "Vendor Contacts"
    assert_match(/\.generated-template--vendor-contacts\s*\{[^}]*gap:\s*8px/m, rendered)
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
    assert_select ".generated-template--vendor-contacts__contact", text: "Ada Fixture", count: 1
    assert_select ".generated-template--vendor-contacts__contact", text: "Grace Fixture", count: 1
    assert_select ".generated-template--vendor-contacts__contact", text: "Brooke Planner", count: 1
    assert_select "table tbody tr td", text: "Sunshine Catering", count: 1
    assert_select "table tbody tr td", text: "Bright Lights Production", count: 1
    assert_select "table tbody tr td", text: "Stationery Studio", count: 1
    assert_select "table tbody tr td", text: "Silent Vendor", count: 1
    assert_select "table tbody tr td", text: "House Band", count: 1
    assert_select ".generated-template--vendor-contacts__contact", text: "Ivy Sound", count: 1
    assert_no_match(/Unselected Band Manager/, rendered)
    assert_equal 6, rows.count
    vendor_groups = fragment.css("table.generated-template--vendor-contacts__table > tbody.generated-template--vendor-contacts__group")

    assert_equal 6, vendor_groups.size
    vendor_groups.each do |vendor_group|
      assert_equal 1, vendor_group.xpath("./tr").size
      assert_equal 1, vendor_group.css("td.generated-template--vendor-contacts__contacts-cell[colspan='2']").size
      assert_empty vendor_group.css("table.generated-template--vendor-contacts__contacts-table")
      contact_rows = vendor_group.css(".generated-template--vendor-contacts__contacts-list > .generated-template--vendor-contacts__contact-row")
      assert contact_rows.any?
      assert contact_rows.all? { |contact_row| contact_row.xpath("./div").size == 2 }
    end
    stationery_group = vendor_groups.find { |vendor_group| vendor_group.text.include?("Stationery Studio") }
    assert_not_nil stationery_group
    assert_equal 2, stationery_group.css(".generated-template--vendor-contacts__contact-row").size
    assert_includes stationery_group.text.squish,
                    "Stationery Stationery Studio Avery Ink 555-111-2222 On-Site Contact 555-222-3333 Vendor meals available for two staff."
    silent_vendor_group = vendor_groups.find { |vendor_group| vendor_group.text.include?("Silent Vendor") }
    assert_not_nil silent_vendor_group
    silent_contact_cells = silent_vendor_group.css(".generated-template--vendor-contacts__contact-row > div")
    assert_equal [ "", "" ], silent_contact_cells.map { |cell| cell.text.strip }
    named_contact_rows = vendor_groups.flat_map { |vendor_group| vendor_group.css(".generated-template--vendor-contacts__contact-row") }
    named_contact_without_phone = named_contact_rows.find do |contact_row|
      cells = contact_row.xpath("./div")
      cells.first.text.strip.present? && cells.last.text.strip == "—"
    end
    assert_not_nil named_contact_without_phone
    assert_empty fragment.css("[rowspan]")
    assert_match(/Planning Pineapple Productions Ada Fixture 555-111-2222/, rows.first.text.squish)
    assert_includes rows.first.text.squish, "Pineapple meals available for four planners."
    assert rows.map { |row| row.text.squish }.any? { |text| text.include?("Catering Sunshine Catering Maria Cater 555-123-4567") }
    team_meal_cells = fragment.css(".generated-template--vendor-contacts__team-meals")
    assert team_meal_cells.any? { |cell| cell.text.strip.empty? }
    assert team_meal_cells.none? { |cell| cell.text.strip == "\u2014" }
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

  test "does not duplicate a real planning company event vendor" do
    planning_company = global_vendors(:pineapple_productions)
    contact = planning_company.contacts.create!(name: "Duplicate Planning Contact", phone: "555-777-1212")
    planning_company.update!(name: "Pineapple Planning Company")
    planning_event_vendor = event_vendors(:pineapple_one)
    planning_event_vendor.update!(team_meals: "Duplicate planning meals")
    planning_event_vendor.replace_contact_ids!([ contact.id ])

    render template: "generated_documents/sections/vendor_contacts", locals: { render_base_styles: false }

    assert_select "table tbody tr td", text: "Pineapple Planning Company", count: 1
    assert_select "table tbody tr td", text: "Pineapple Productions", count: 0
    assert_no_match(/Duplicate Planning Contact|555-777-1212|Duplicate planning meals/, rendered)
  end

  private

  def create_event_vendor(name:, contacts:, social_handle: nil, **attributes)
    global_vendor = GlobalVendor.create!(
      name: name,
      default_social_handle: social_handle,
      contacts_attributes: contacts
    )
    event_vendor = @event.event_vendors.create!(global_vendor: global_vendor, **attributes)
    event_vendor.replace_contact_ids!(global_vendor.contacts.ids)
    event_vendor
  end
end
